# TFE v4 Quick Install on AWS
This module is intended for **internal** HashiCorp users and/or partners to quickly deploy a TFE v4 instance in AWS. 

**This repository (terraform-chip-tfe-is-terraform-aws-ptfe-v4-quick-install) is not maintained** - Please contact your HashiCorp contact to obtain an updated fork. 

It is close to but not quite production-ready and **__should not__** be used for an enterprise customer production deployment. The _Operational Mode_ is **External Services** and the _Installation Method_ is **Online**. See the [examples](./examples) page for detailed deployment scenarios & instructions. Several assumptions are made and default values are set for some of the resource arguements to reduce complexity and the amount of input variables (see the [Security Caveats](##Security-Caveats) section).


## Requirements
- Terraform >= 0.12.6
- TFE license file from Replicated (named `tfe-license.rli`) locally in Terraform working directory


## Prerequisites
- AWS account
- VPC with subnets (preferably both public _and_ private) that have outbound Internet connectivity
- _One_ of the following:
    - (_Public_) Route53 Hosted Zone (needs to be _public_ for DNS certificate validation to work with AWS Certificate Manager)
    - TLS/SSL certificate (imported into ACM or IAM) with desired TFE hostname
<p>&nbsp;</p>

## Usage

### Deployment
See the [examples](./examples) page on how to source this module into a Terraform configuration and deploy.

### Logging In
After the module has been deployed and the EC2 instance created by the Autoscaling Group has finished initializing, open a web browser and log in to the new TFE instance via the URL in the output value of `tfe_url`. The username defaults to `admin` unless a value was specified for the input variable `tfe_initial_admin_username`.  The password is the value of `random_password.tfe_initial_admin_pw.result` (found in the Terraform state) unless a value was specified for the input variable `tfe_initial_admin_pw`.
<p>&nbsp;</p>


## Required Inputs
| Name | Type | Description | Default Value |
| -------- | ---- | ----------- | ------------- |
| friendly_name_prefix | string | String value for freindly name prefix for unique AWS resource names and tags | |
| tfe_hostname | string | Hostname of TFE instance | |
| tfe_license_file_path | string | Local file path to tfe-license.rli file including file name | |
| vpc_id | string | VPC ID that TFE will be deployed into | |
| alb_subnet_ids | list | List of Subnet IDs to use for Application Load Balancer (ALB) | |
| ec2_subnet_ids | list | List of Subnet IDs to use for EC2 instance - preferably private subnets | |
| rds_subnet_ids | list | Subnet IDs to use for RDS Database Subnet Group - preferably private subnets | |
<p>&nbsp;</p>


## Optional Inputs
| Name | Type | Description | Default Value |
| -------- | ---- | ----------- | ------------- |
| common_tags | map | Map of common tags for taggable AWS resources | {} |
| tfe_release_sequence | string | TFE application version release sequence number within Replicated (leave blank for latest version) | "" |
| tfe_initial_admin_username | string | Username for initial TFE local adminitrator account | admin |
| tfe_initial_admin_email | string | Email address for initial TFE local adminitrator account | tfe_admin@changemelater.com |
| tfe_initial_admin_pw | string | Login password for TFE initial admin user created by this module - must be > 8 characters | "" |
| tfe_initial_org_name | string | Name of initial TFE Organization created by bootstrap process / cloud-init script | initial-admin-org |
| tfe_initial_org_email | string | Email address of initial TFE Organization created by bootstrap process / cloud-init script | initial-admin-org@changemelater.com |
| route53_hosted_zone_name | string | Route53 Hosted Zone where TFE Alias Record and Certificate Validation record will reside (required if `tls_certificate_arn` is left blank) | "" |
| ingress_cidr_alb_allow | list | List of CIDR ranges to allow web traffic ingress to TFE Application Load Balancer | [0.0.0.0/0] |
| ingress_cidr_ec2_allow | list | List of CIDRs to allow SSH ingress to TFE EC2 instance | [] |
| tls_certificate_arn | string | ARN of ACM or IAM certificate to be used for Application Load Balancer HTTPS listeners (required if `route53_hosted_zone_name` is left blank) | "" |
| kms_key_arn | string | ARN of KMS key to encrypt TFE S3 and RDS resources | "" |
| ssh_key_pair | string | "Name of SSH key pair for TFE EC2 instance" | "" |
| os_type | string | OS type for TFE EC2 instance | amzn2 |
| instance_size | string | EC2 instance type for TFE server | m5.large |
| rds_storage_capacity | string | Size capacity (GB) of RDS PostgreSQL database | 50 |
| rds_engine_version | string | Version of PostgreSQL for RDS engine | 11 |
| rds_multi_az | string | Set to true to enable multiple availability zone RDS | true |
| rds_instance_size | string | Instance size for RDS | db.m4.large |
<p>&nbsp;</p>


## Outputs
| Name | Description |
| -------- | ---- |
| tfe_url | URL to access TFE application |
| tfe_admin_console_url | URL to access TFE Replicated admin console |
| tfe_alb_dns_name | DNS name of TFE Application Load Balancer (ALB) |
| tfe_s3_app_bucket_name | TFE application S3 bucket name |
<p>&nbsp;</p>


## Security Caveats
The main reasons for the disclaimer that this module is not considered 100% production-ready for an enterprise customer is related to how secrets are handled. It is best practice to avoid having secrets as Terraform variables that will end up in Terraform state whenever possible.

### Secrets Management
There are mainly four sensitive values when fully automating a TFE v4 deployment on AWS:

1. **RDS password (`random_password.rds_password`)** - this value has to go into Terraform state regardless, as it is a required arguement for the `aws_db_instance` Terraform resource. This module computes this value within Terraform via the `random_password` resource. Always make sure to appropriately protect Terraform state files. In order to achieve full automation, several RDS attribute values (including the RDS password) need to be placed in a `tfe-settings.json` file on the TFE instance. For the RDS password value specifically, the key name is `pg_password`. Again, since this value is going to be in Terraform state anyways, it is interpolated into the `template_file.tfe_user_data` data source for the user_data script. This one is more of an FYI.  
2. **Replicated console password (`random_password.console_password`)** - this is the password to unlock the Replicated admin console. In order to achieve full automation, this value needs to be placed in `/etc/replicated.conf` on the TFE instance, with a key name of `DaemonAuthenticationPassword`. It is possible to use LDAP here but I have not seen it in practice _(it may be more work than it's worth)_. This module computes this value within Terraform via the `random_password` resource, which means this value will be in Terraform state. A better approach would be to have the `user_data` script retrieve the secret at build time from a proper secrets management system such as Vault, or even AWS Secrets Manager. Or, if the customer is comfortable with it, another approach could be to store the `replicated.conf` file in a highly locked down, encrypted S3 bucket.  
3. **Embedded Vault encryption password (`random_password.enc_password`)** - this only applies to deployments leveraging the embedded Vault _(which is the extremely highly recommended best practice at this point)_. This is considered _"secret zero"_ that encrypts the single Vault unseal key and Vault root token before they are written into the TFE PostgreSQL database. In order to achieve full automation, this value needs to be placed in a `tfe-settings.json` file on the TFE instance, with a key name of `enc_password`. This module computes this value within Terraform via the `random_password` resource, which means this value will be in Terraform state. A better approach would be to have the `user_data` script retrieve the secret at build time from a secrets management system such as Vault, or even AWS Secrets Manager. Or, if the customer is comfortable with it, another approach could be to store the `tfe-settings.json` file in a highly locked down, encrypted S3 bucket.  
4. **Initial admin user password (`var.tfe_initial_admin_pw`)** - one of the reasons this module is called "quick-install" is because as part of the bootsrap process, an initial admin user is created leveraging the [Initial Admin Creation Token](https://www.terraform.io/docs/enterprise/install/automating-initial-user.html#initial-admin-creation-token-iact-). In most cases, it is better to omit this functionality from an enterprise customer production deployment as they are more comfortable with setting up the initial admin user and organization in the TFE UI. This way, they can generate and store the password value in their own proper secrets management tool. This variable is optional; if left unspecified, the `random_password.tfe_initial_admin_pw` resource will take precedence.


### Other Security Hardening
Security and hardening largely depends on customers' environments, existing/available tooling, internal practices/policies/procedures, and comfort level. Here are some other tweaks a customer may want to make:
- Disable/block SSH, and use something else like **AWS Systems Manager (SSM Agent)** for shell access to TFE instance
- Specify source CIDR block(s) for ingress traffic allowed to hit the TFE Application Load Balancer, instead of opening it up to `0.0.0.0/0`
- Enable **SELinux** ([only specific conditions are supported](https://www.terraform.io/docs/enterprise/before-installing/index.html#linux-instance))
<p>&nbsp;</p>


## Troubleshooting
To monitor the progress of the install process (cloud-init), SSH into the EC2 instance and run `journalctl -xu cloud-final -f` to tail the logs. Or, to review the logs once the cloud-init process has finished, run `journalctl -xu cloud-final cat -o`.
