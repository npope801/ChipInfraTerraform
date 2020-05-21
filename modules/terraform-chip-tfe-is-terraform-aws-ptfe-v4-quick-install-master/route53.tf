data "aws_route53_zone" "selected" {
  count        = var.route53_hosted_zone_name != "" ? 1 : 0
  name         = var.route53_hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "tfe_alb_alias_record" {
  count   = var.route53_hosted_zone_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.tfe_hostname
  type    = "A"

  alias {
    name                   = aws_lb.tfe_alb.dns_name
    zone_id                = aws_lb.tfe_alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "tfe_cert_validation_record" {
  count   = length(aws_acm_certificate.tfe_cert) == 1 && var.route53_hosted_zone_name != "" ? 1 : 0
  name    = aws_acm_certificate.tfe_cert[0].domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.tfe_cert[0].domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.selected[0].zone_id
  records = [aws_acm_certificate.tfe_cert[0].domain_validation_options[0].resource_record_value]
  ttl     = 60
}