locals {
  vpc_cidr = "10.123.0.0/16"
}

locals {
  security_groups = {
    public = {
      name        = "public_sg"
      description = "public access"
      ingress = {
        open = {
          from        = 0
          to          = 0
          protocol    = -1
          cidr_blocks = [var.access_ip]
        }
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
        https = {
          from        = 443
          to          = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }

        custom = {
          from        = 6443
          to          = 6443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"] #jenkins server sec group
        }
        ssh = {
          from        = 22
          to          = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"] #jenkins server sec group
        }
      }
    }
    loadbalancer = {
      name        = "loadbalancer_sg"
      description = "loadbalancer access"
      ingress = {
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
        https = {
          from        = 443
          to          = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }
}