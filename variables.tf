variable "aws_region" {
  default = "us-east-1"
}

variable "access_ip" {}

#-------database variables

variable "zone_id" {
  type        = string
  default     = "Z0316813CHGSR83NJNTD"
  description = "Route53 hosted zone ids"
}
variable "domain_name" {
  default = "mehmetafsar.net"
}
variable "cname" {
  default = "rancher"
}