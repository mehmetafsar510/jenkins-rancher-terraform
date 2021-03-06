output "acm_arn" {
    value = aws_acm_certificate_validation.cert_validation.certificate_arn 
}

output "domainname" {
    value = join("", ["https://", "rancher.${var.domain_name}"])
  
}