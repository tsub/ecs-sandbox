locals {
  project_name          = "tsub-sandbox"
  route53_zone          = "sandbox.tsub.me"
  athena_partition      = "year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  log_retention_in_days = 7
}
