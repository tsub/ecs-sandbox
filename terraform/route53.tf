data "aws_route53_zone" "main" {
  name = local.route53_zone
}

resource "aws_route53_record" "wildcard-validation" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_type
  ttl     = "300"

  records = [aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_value]
}
