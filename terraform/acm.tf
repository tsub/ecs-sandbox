resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${local.route53_zone}"
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [aws_route53_record.wildcard-validation.fqdn]
}
