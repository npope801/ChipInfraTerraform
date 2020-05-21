
#
# VPCs
#

locals {
    west-cidr           = "10.0.0.0/16"
    eu-central-cidr     = "10.1.0.0/16"
    west-routes         = [ 
            for pair in setproduct(module.eu-central-vpc.public_subnets_cidr_blocks, module.west-vpc.public_route_table_ids) :{
                cidr_block = pair[0]
                route_table_id = pair[1]
              }
            ]
    eu-central-routes   = [ 
            for pair in setproduct(module.west-vpc.public_subnets_cidr_blocks, module.eu-central-vpc.public_route_table_ids) :{
                cidr_block = pair[0]
                route_table_id = pair[1]
              }
            ]
}

data "aws_availability_zones" "west-azs" {
  provider = aws.us-west-1
  state = "available"
}

module "west-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "west-vpc"
  cidr = local.west-cidr
  azs  = data.aws_availability_zones.west-azs.names
  public_subnets  = [
      for az in data.aws_availability_zones.west-azs.names:
      cidrsubnet(local.west-cidr, 8, index(data.aws_availability_zones.west-azs.names, az)+1)
  ]
  private_subnets = [
      for az in data.aws_availability_zones.west-azs.names:
      cidrsubnet(local.west-cidr, 8, index(data.aws_availability_zones.west-azs.names, az)+10)
  ]
  create_database_subnet_group = true
  database_subnets = [
      for az in data.aws_availability_zones.west-azs.names:
      cidrsubnet(local.west-cidr, 8, index(data.aws_availability_zones.west-azs.names, az)+20)
  ]
  enable_nat_gateway = true
  providers = {
    aws = aws.us-west-1
  }
}

data "aws_availability_zones" "eu-central-azs" {
  provider = aws.eu-central-1
  state = "available"
}

module "eu-central-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "eu-central-vpc"
  cidr = local.eu-central-cidr
  azs  = data.aws_availability_zones.eu-central-azs.names
  public_subnets  = [
      for az in data.aws_availability_zones.eu-central-azs.names:
      cidrsubnet(local.eu-central-cidr, 8, index(data.aws_availability_zones.eu-central-azs.names, az)+1)
  ]
  private_subnets = [
      for az in data.aws_availability_zones.eu-central-azs.names:
      cidrsubnet(local.eu-central-cidr, 8, index(data.aws_availability_zones.eu-central-azs.names, az)+10)
  ]
  create_database_subnet_group = true
  database_subnets = [
      for az in data.aws_availability_zones.eu-central-azs.names:
      cidrsubnet(local.eu-central-cidr, 8, index(data.aws_availability_zones.eu-central-azs.names, az)+20)
  ]
  enable_nat_gateway = true
  providers = {
    aws = aws.eu-central-1
  }
}

resource "aws_vpc_peering_connection" "peer" {
  provider      = aws.us-west-1
  vpc_id        = module.west-vpc.vpc_id
  peer_vpc_id   = module.eu-central-vpc.vpc_id
  peer_region   = "eu-central-1"
  auto_accept   = false
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.eu-central-1
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

resource "aws_default_security_group" "west-vpc" {
  provider = aws.us-west-1
  vpc_id   = module.west-vpc.vpc_id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_default_security_group" "eu-central-vpc" {
  provider = aws.eu-central-1
  vpc_id   = module.eu-central-vpc.vpc_id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route" "west-vpc" {
  for_each                  = {
      for cidrroute in local.west-routes : "${cidrroute.cidr_block}.${cidrroute.route_table_id}" => cidrroute
  }
  provider                  = aws.us-west-1
  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "eu-central-vpc" {
  for_each                  = {
      for cidrroute in local.eu-central-routes : "${cidrroute.cidr_block}.${cidrroute.route_table_id}" => cidrroute
  }
  provider                  = aws.eu-central-1
  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
} 

#
# End of VPCs
#

#
# TFE
#

resource "random_id" "project_name" {
  byte_length = 3
}

resource "tls_private_key" "aws_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "aws_ssh_key" {
  key_name   = "${random_id.project_name.hex}-ssh-key"
  public_key = tls_private_key.aws_ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
    content     = tls_private_key.aws_ssh_key.private_key_pem
    filename = "${path.module}/private.pem"
}

resource "tls_self_signed_cert" "example" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.aws_ssh_key.private_key_pem
  subject {
    common_name  = module.tfe.tfe_alb_dns_name
    organization = "ACME Examples, Inc"
  }
  validity_period_hours = 12
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.aws_ssh_key.private_key_pem
  certificate_body = tls_self_signed_cert.example.cert_pem
}

module "tfe" {
  source = "./modules/terraform-chip-tfe-is-terraform-aws-ptfe-v4-quick-install-master"
  friendly_name_prefix       = "tfe"
  tfe_hostname               = module.tfe.tfe_alb_dns_name
  tfe_license_file_path      = "terraform-chip.rli"
  vpc_id                     = module.west-vpc.vpc_id
  alb_subnet_ids             = module.west-vpc.public_subnets
  ec2_subnet_ids             = module.west-vpc.private_subnets
  rds_subnet_ids             = module.west-vpc.database_subnets
  tls_certificate_arn        = aws_acm_certificate.cert.id
  tfe_initial_admin_pw       = "SomethingSecure!"
  tfe_initial_admin_username = "tfe-admin"
  tfe_initial_admin_email    = "nick@observian.com"
}

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "tfe_admin_console_url" {
  value = module.tfe.tfe_admin_console_url
}

output "alb_dns_name" {
  value = module.tfe.tfe_alb_dns_name
}

#
# End of TFE
#