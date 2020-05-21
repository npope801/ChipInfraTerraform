##################################
# DNS
##################################
output "tfe_url" {
  value = "https://${var.tfe_hostname}"
}

output "tfe_admin_console_url" {
  value = "https://${var.tfe_hostname}:8800"
}

output "tfe_alb_dns_name" {
  value = aws_lb.tfe_alb.dns_name
}

##################################
# S3
##################################
output "tfe_s3_app_bucket_name" {
  value = aws_s3_bucket.tfe_app.id
}
