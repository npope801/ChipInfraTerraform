# Examples
 - Example 1 - ["Bare Bones" w/ Route53 and ACM](##Example-1---"Bare-Bones"-w/-Route53-and-ACM)
 - Example 2 - ["Bare Bones" w/ Existing TLS/SSL Certificate](##Example-2---"Bare-Bones"-w/-Existing-TLS/SSL-Certificate)
 - Example 3 - ["Best Practice" w/ Route53 and ACM](##Example-3---"Best-Practice"-w/-Route53-and-ACM)
 - Example 4 - ["Best Practice" w/ Existing TLS/SSL Certificate](##Example-4---"Best-Practice"-w/-Existing-TLS/SSL-Certificate)
<p>&nbsp;</p>

## Example 1 - "Bare Bones" w/ Route53 and ACM
In this first example, the user wants to specify the bare minimum amount of inputs. The only optional variable inputted is `route53_hosted_zone_name`. When `tls_certificate_arn` is not specified, `route53_hosted_zone_name` becomes required (and vice versa). The reason is this module provisions an Application Load Balancer with HTTPS listeners, which require a TLS/SSL certificate to be configured at creation time. 

The user has an existing AWS Route53 Hosted Zone of which this module will create an Alias Record within (pointed at the DNS name of the Application Load Balancer to be created), as well as a Certificate Validation record for the TLS/SSL certiciate that will be created within AWS Certificate Manager (ACM).

```hcl
provider "aws" {
  region = "us-east-1"
}

module "tfe" {
  source = "github.com/hashicorp/is-terraform-aws-ptfe-v4-quick-install"

  friendly_name_prefix       = var.friendly_name_prefix
  tfe_hostname               = var.tfe_hostname
  tfe_license_file_path      = var.tfe_license_file_path
  vpc_id                     = var.vpc_id
  alb_subnet_ids             = var.alb_subnet_ids
  ec2_subnet_ids             = var.ec2_subnet_ids
  rds_subnet_ids             = var.rds_subnet_ids
  route53_hosted_zone_name   = var.route53_hosted_zone_name
}

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "tfe_admin_console_url" {
  value = module.tfe.tfe_admin_console_url
}
```
<p>&nbsp;</p>


## Example 2 - "Bare Bones" w/ Existing TLS/SSL Certificate
In this second example, specifying the bare minimum amount of inputs is also desired, however the user does not have an AWS Route53 Hosted Zone configured and would rather handle their own DNS outside of AWS. The user also prefers to provision a TLS/SSL certificate with something outside of AWS. Therefore, the `tls_certificate_arn` input is required since there will be no `route53_hosted_zone_name` inputted. This means the user has an existing TLS/SSL certificate either imported in to AWS Certificate Manager (ACM) or IAM. The caveat here is that there needs to be a DNS CNAME record created for the desired TFE hostname pointed at the Application Load Balancer (ALB) DNS name _as soon as it is known_ for the bootstrap automation to fully function properly. The ALB DNS name is not known until this module has actually provisioned the ALB (the other option I am considering is to have the bootstrap logic temporarily set the TFE hostname to the ALB DNS name so the cloud-init process can complete without error - but then the user would have to manually go in to the TFE admin console after the module is deployed and after the custom DNS CNAME record is created to update the TFE hostname to the actual desired hostname).

```hcl
provider "aws" {
  region = "us-east-1"
}

module "tfe" {
  source = "github.com/hashicorp/is-terraform-aws-ptfe-v4-quick-install"

  friendly_name_prefix       = var.friendly_name_prefix
  tfe_hostname               = var.tfe_hostname
  tfe_license_file_path      = var.tfe_license_file_path
  vpc_id                     = var.vpc_id
  alb_subnet_ids             = var.alb_subnet_ids
  ec2_subnet_ids             = var.ec2_subnet_ids
  rds_subnet_ids             = var.rds_subnet_ids
  tls_certificate_arn        = var.tls_certificate_arn
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
```
<p>&nbsp;</p>

### Notes on "Bare Bones" examples
Here are the ramifications of not leveraging some of the other optional inputs listed below (this applies to all use cases):
- `common_tags` - No "common" tags on AWS resources (tagging resources is a best practice)
- `tfe_release_sequence` - No TFE version specified in code, so the module will always pull down the latest at the point in time the EC2 instance is created (this will continue to happen anytime the Autoscaling Group creates subsequent EC2 instances
- `tfe_initial_admin_username` - will default to `admin`
- `tfe_initial_admin_email` - will default to `tfe_admin@changemelater.com` which is invalid
- `tfe_initial_admin_pw` - if not specified, defaults to the value of `random_password.tfe_initial_admin_pw` (found in the Terraform state)
- `tfe_initial_org_name` - defaults to `initial-admin-org`
- `tfe_initial_org_email` - defaults to `initial-admin-org@changemelater.com` which is invalid
- `route53_hosted_zone_name` - Route53 will not be used for Alias Record / CNAME (assumed that user is doing their own DNS), & module will not be able to create & validate AWS Certificate Manager (ACM) TLS/SSL certificate
- `ingress_cidr_alb_allow` - defaults to `[0.0.0.0/0]`; Application Load Balancer (ALB) will be opened up to the world (sometimes OK)
- `ingress_cidr_ec2_allow` - defaults to `[]`; EC2 instance will not be accessible by IP (sometimes OK)
- `kms_key_arn` - KMS will not be used to encrypt S3 and RDS
- `tls_certificate_arn` - user does not have an existing TLS/SSL certificate imported into ACM or IAM, and prefers to have the module create & validate a new cert via **Route53** and **AWS Certfiicate Manager**
- `ssh_key_pair` - no SSH key pair will be added to Launch Template / EC2 instance
<p>&nbsp;</p>

_Examples 3 and 4 (below) fall more in line with the best practices most customers want to adhere to, and therefore are more realistic examples of TFE v4 deployment._
<p>&nbsp;</p>


## Example 3 - "Best Practice" w/ Route53 and ACM
Example 3 is more in line with a configuration many users & customers prefer to deploy, and probably considered the best option out of all the examples on this page. A number of the `tfe_*` inputs are leveraged to customize the bootstrap automation & initial configuration of the TFE application itself. A `route53_hosted_zone_name` is provided, such that the module will provision a Route53 Alias Record pointed at the Application Load Balancer (ALB) DNS name, as well as provision & validate a TLS/SSL certicicate in AWS Certificate Manager (ACM).

```hcl
provider "aws" {
  region = "us-east-1"
}

module "tfe" {
  source = "github.com/hashicorp/is-terraform-aws-ptfe-v4-quick-install"

  friendly_name_prefix       = "my-unique-prefix"
  common_tags                = {
                                 "Environment" = "Test"
                                 "Tool"        = "Terraform"
                                 "Owner"       = "YourName"
                               }
  tfe_hostname               = "my-tfe-instance.whatever.com"
  tfe_license_file_path      = "./tfe-license.rli"
  tfe_release_sequence       = "414"
  tfe_initial_admin_username = "tfe-local-admin"
  tfe_initial_admin_email    = "tfe-admin@whatever.com"
  tfe_initial_admin_pw       = "ThisAintSecure123!"
  tfe_initial_org_name       = "whatever-org"
  tfe_initial_org_email      = "tfe-admins@whatever.com"
  vpc_id                     = "vpc-00000000000000000"
  alb_subnet_ids             = ["subnet-00000000000000000", "subnet-11111111111111111", "subnet-22222222222222222"]
  ec2_subnet_ids             = ["subnet-33333333333333333", "subnet-44444444444444444", "subnet-55555555555555555"]
  route53_hosted_zone_name   = "whatever.com"
  kms_key_arn                = "arn:aws:kms:us-east-1:000000000000:key/00000000-1111-2222-3333-444444444444"
  ingress_cidr_alb_allow     = ["0.0.0.0/0"]
  ingress_cidr_ec2_allow     = ["1.1.1.1/32"] # my workstation IP
  ssh_key_pair               = "my-key-pair-us-east-1"
  rds_subnet_ids             = ["subnet-33333333333333333", "subnet-44444444444444444", "subnet-55555555555555555"]

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "tfe_admin_console_url" {
  value = module.tfe.tfe_admin_console_url
}
```
<p>&nbsp;</p>


## Example 4 - "Best Practice" w/ Existing TLS/SSL Certificate
The main difference between Example 3 and this Example 4 is providing a value for the `tls_certificate_arn` input and omitting the `route53_hosted_zone_name` input. It is assumed that the user already has a TLS/SSL certificate imported into AWS Certificate Manager (ACM) or IAM, & also that the customer is going to do their own DNS outside of AWS. The customer must create a CNAME record pointed at the Application Load Balancer (ALB) DNS name _as soon as it is known_ for this scenario to fully function properly. Just like Example 2, this is challenging with timing because the ALB DNS name is not known until this module has actually provisioned the ALB (the other option I am considering is to have the bootstrap logic temporarily set the TFE hostname to the ALB DNS name so the cloud-init process can complete without error - but then the user would have to manually go in after the module is deployed and after the custom DNS CNAME record is created and update the TFE hostname in the TFE admin console to the actual desired hostname). This is why Example 3 would be preferred over Example 4.

```hcl
provider "aws" {
  region = "us-east-1"
}

module "tfe" {
  source = "github.com/hashicorp/is-terraform-aws-ptfe-v4-quick-install"

  friendly_name_prefix       = "my-unique-prefix"
  common_tags                = {
                                 "Environment" = "Test"
                                 "Tool"        = "Terraform"
                                 "Owner"       = "YourName"
                               }
  tfe_hostname               = "my-tfe-instance.whatever.com"
  tfe_license_file_path      = "./tfe-license.rli"
  tfe_release_sequence       = "414"
  tfe_initial_admin_username = "tfe-local-admin"
  tfe_initial_admin_email    = "tfe-admin@whatever.com"
  tfe_initial_admin_pw       = "ThisAintSecure123!"
  tfe_initial_org_name       = "whatever-org"
  tfe_initial_org_email      = "tfe-admins@whatever.com"
  vpc_id                     = "vpc-00000000000000000"
  alb_subnet_ids             = ["subnet-00000000000000000", "subnet-11111111111111111", "subnet-22222222222222222"]
  ec2_subnet_ids             = ["subnet-33333333333333333", "subnet-44444444444444444", "subnet-55555555555555555"]
  tls_certificate_arn        = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-1111-2222-3333-444444444444"
  kms_key_arn                = "arn:aws:kms:us-east-1:000000000000:key/00000000-1111-2222-3333-444444444444"
  ingress_cidr_alb_allow     = ["0.0.0.0/0"]
  ingress_cidr_ec2_allow     = ["1.1.1.1/32"] # my workstation IP
  ssh_key_pair               = "my-key-pair-us-east-1"
  rds_subnet_ids             = ["subnet-33333333333333333", "subnet-44444444444444444", "subnet-55555555555555555"]

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "tfe_admin_console_url" {
  value = module.tfe.tfe_admin_console_url
}

output "alb_dns_name" {
  value = module.tfe.tfe_alb_dns_name
}
```
