################################################
# Main
################################################
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

################################################
# IAM
################################################
data "template_file" "instance_role_policy_kms" {
  count    = var.kms_key_arn != "" ? 1 : 0
  template = file("${path.module}/templates/tfe-instance-role-policy-kms.json")

  vars = {
    tfe_s3_app_bucket_arn = aws_s3_bucket.tfe_app.arn
    aws_kms_arn           = var.kms_key_arn
  }
}

data "template_file" "instance_role_policy" {
  count    = var.kms_key_arn == "" ? 1 : 0
  template = file("${path.module}/templates/tfe-instance-role-policy.json")

  vars = {
    tfe_s3_app_bucket_arn = aws_s3_bucket.tfe_app.arn
  }
}

################################################
# Compute
################################################
data "aws_ami" "tfe_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0*-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "template_file" "tfe_user_data" {
  template = "${file("${path.module}/templates/tfe_${var.os_type}_user_data.sh")}"

  vars = {
    tfe_hostname               = var.tfe_hostname
    tfe_license_file           = filebase64(var.tfe_license_file_path)
    tfe_release_sequence       = var.tfe_release_sequence
    tfe_initial_admin_username = var.tfe_initial_admin_username
    tfe_initial_admin_email    = var.tfe_initial_admin_email
    tfe_initial_admin_pw       = element(coalescelist(random_password.tfe_initial_admin_pw[*].result, list(var.tfe_initial_admin_pw)), 0)
    tfe_initial_org_name       = var.tfe_initial_org_name
    tfe_initial_org_email      = var.tfe_initial_org_email
    console_password           = random_password.console_password.result
    enc_password               = random_password.enc_password.result
    s3_app_bucket_name         = aws_s3_bucket.tfe_app.id
    s3_app_bucket_region       = data.aws_region.current.name
    kms_key_arn                = var.kms_key_arn
    pg_netloc                  = aws_db_instance.tfe_rds.endpoint
    pg_dbname                  = aws_db_instance.tfe_rds.name
    pg_user                    = aws_db_instance.tfe_rds.username
    pg_password                = aws_db_instance.tfe_rds.password
  }
}

data "template_cloudinit_config" "tfe_cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "tfe_cloud_init.txt"
    content_type = "text/x-shellscript"
    content      = data.template_file.tfe_user_data.rendered
  }
}

################################################
# S3
################################################
data "template_file" "tfe_s3_app_bucket_policy" {
  template = file("${path.module}/templates/tfe-s3-app-bucket-policy.json")

  vars = {
    tfe_s3_app_bucket_arn     = aws_s3_bucket.tfe_app.arn
    current_iam_caller_id_arn = data.aws_caller_identity.current.arn
    tfe_iam_role_arn          = aws_iam_role.tfe_instance_role.arn
  }
}


