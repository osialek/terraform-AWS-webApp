variable "web_server_ingress_rules" {
  type = map(object(
    {
      description = string
      port        = number
      protocol    = string
      cidr_blocks = list(string)
    }
  ))
  default = {
    "80" = {
      description = "Port 80"
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    "443" = {
      description = "Port 443"
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
variable "web_server_egress_rules" {
  type = map(object(
    {
      description = string
      port        = number
      protocol    = string
      cidr_blocks = list(string)
    }
  ))
  default = {
    "internet" = {
      description = "Access to internet - egress only (stateful)"
      port        = "0"
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
variable "common_nacl_ingress_rules" {
  type = map(object(
    {
      protocol   = string
      rule_no    = number
      action     = string
      cidr_block = string
      from_port  = number
      to_port    = number
    }
  ))
  default = {
    # Allow IN traffic for user/server applications & clients    
    "ephemeral ports" = {
      protocol   = "tcp"
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 1024
      to_port    = 65535
    }
    # Allow IN all traffic from AWS internal network
    "internal_network" = {
      protocol   = "-1"
      rule_no    = 101
      action     = "allow"
      cidr_block = "10.0.0.0/16"
      from_port  = 0
      to_port    = 0
    }
  }
}
variable "common_nacl_egress_rules" {
  type = map(object(
    {
      protocol   = string
      rule_no    = number
      action     = string
      cidr_block = string
      from_port  = number
      to_port    = number
    }
  ))
  default = {
    "allow_all" = {
      protocol   = "-1"
      rule_no    = 200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
    }
  }
}

variable "instance_replica_count" {
  type    = number
  default = 1
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "private_subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}
variable "public_subnet_cidr" {
  type    = string
  default = "10.0.100.0/24"
}
variable "zone_ids" {
  type    = list(string)
  default = ["euc1-az1", "euc1-az2", "euc1-az3"]
}
# variable "region" {
#   type    = string
#   default = "eu-central-1"
# }
variable "environment" {
  type = string
}
variable "app_identifier" {
  type    = string
  default = "Website123"
}
variable "instance_type_db_server" {
  type = string
}
variable "instance_type_web_server" {
  type = string
}