# --- root/main.tf --- 

#Deploy Networking Resources

module "networking" {
  source           = "./modules/networking"
  vpc_cidr         = local.vpc_cidr
  private_sn_count = 3
  public_sn_count  = 2
  private_cidrs    = [for i in range(1, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)]
  public_cidrs     = [for i in range(2, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)]
  max_subnets      = 20
  access_ip        = var.access_ip
  security_groups  = local.security_groups
  db_subnet_group  = "true"
}

module "loadbalancing" {
  source                  = "./modules/loadbalancing"
  public_subnets          = module.networking.public_subnets
  tg_port                 = 80
  tg_protocol             = "HTTP"
  vpc_id                  = module.networking.vpc_id
  elb_healthy_threshold   = 2
  elb_unhealthy_threshold = 2
  elb_timeout             = 3
  elb_interval            = 30
  listener_port           = 443
  listener_protocol       = "HTTPS"
  certificate_arn_elb     = module.route53.acm_arn
}

module "compute" {
  source              = "./modules/compute"
  public_sg           = module.networking.public_sg
  public_subnets      = module.networking.public_subnets
  master_profile_name = module.iam.master_profile_name
  instance_count      = 1
  instance_type       = "t2.small"
  vol_size            = "20"
  public_key_path     = "~/.ssh/id_rsa.pub"
  key_name            = "id_rsa"
  user_data_path      = "${path.root}/userdata.sh"
  lb_target_group_arn = module.loadbalancing.lb_target_group_arn
  tg_port             = 80
}

module "iam" {
  source = "./modules/IAM"
}

module "route53" {
  source      = "./modules/route53"
  dns_name    = module.loadbalancing.lb_endpoint
  zone_id     = var.zone_id
  domain_name = var.domain_name
  cname       = var.cname
}