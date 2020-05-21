provider "aws" {
  region = "us-east-1"
}

# Use Route53 and AWS Certificate Manager (ACM)
module "tfe" {
  source = "github.com/hashicorp/is-terraform-aws-ptfe-v4-quick-install"

  friendly_name_prefix       = var.friendly_name_prefix
  common_tags                = var.common_tags
  tfe_hostname               = var.tfe_hostname
  tfe_license_file_path      = var.tfe_license_file_path
  tfe_release_sequence       = var.tfe_release_sequence
  tfe_initial_admin_username = var.tfe_initial_admin_username
  tfe_initial_admin_email    = var.tfe_initial_admin_email
  tfe_initial_admin_pw       = var.tfe_initial_admin_pw
  tfe_initial_org_name       = var.tfe_initial_org_name
  vpc_id                     = var.vpc_id
  alb_subnet_ids             = var.alb_subnet_ids
  ec2_subnet_ids             = var.ec2_subnet_ids
  route53_hosted_zone_name   = var.route53_hosted_zone_name
  kms_key_arn                = var.kms_key_arn
  ingress_cidr_alb_allow     = var.ingress_cidr_alb_allow
  ingress_cidr_ec2_allow     = var.ingress_cidr_ec2_allow
  ssh_key_pair               = var.ssh_key_pair
  rds_subnet_ids             = var.rds_subnet_ids
}

# Use existing TLS/SSL certificate imported into ACM or IAM
# module "tfe" {
#   source = "github.com/hashicorp/is-terraform-aws-ptfe-v4-quick-install"

#   friendly_name_prefix       = var.friendly_name_prefix
#   common_tags                = var.common_tags
#   tfe_hostname               = var.tfe_hostname
#   tfe_license_file_path      = var.tfe_license_file_path
#   tfe_release_sequence       = var.tfe_release_sequence
#   tfe_initial_admin_username = var.tfe_initial_admin_username
#   tfe_initial_admin_email    = var.tfe_initial_admin_email
#   tfe_initial_admin_pw       = var.tfe_initial_admin_pw
#   tfe_initial_org_name       = var.tfe_initial_org_name
#   vpc_id                     = var.vpc_id
#   alb_subnet_ids             = var.alb_subnet_ids
#   ec2_subnet_ids             = var.ec2_subnet_ids
#   kms_key_arn                = var.kms_key_arn
#   tls_certificate_arn        = var.tls_certificate_arn
#   ingress_cidr_alb_allow     = var.ingress_cidr_alb_allow
#   ingress_cidr_ec2_allow     = var.ingress_cidr_ec2_allow
#   ssh_key_pair               = var.ssh_key_pair
#   rds_subnet_ids             = var.rds_subnet_ids
# }