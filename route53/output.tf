output "public_dns_id" {
  value = length(data.aws_route53_zone.public) > 0 ? data.aws_route53_zone.public[0].id : "nopublic"
}
