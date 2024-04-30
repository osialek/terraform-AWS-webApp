### This module deploys a network with:
# 1 core VPC and 4 subnets in 2 AZs
# 2 public subnets + 2 private subnets
# ASGs for web servers and database with parametarized number of instances desired
# Security groups + NACLs

# AMI used by Web & Database servers
data "aws_ami" "ubuntu_2204_latest" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # <-- Canonical
}

# Fetch current Region
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

############# Network Deployment ##############
# VPC with public and private subnets deployment with VPC Module
module "network-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  name    = "${var.environment}-vpc-${local.region}"
  cidr    = var.vpc_cidr
  # using IDs instead of names to avoid cross-az issues (different mapping) cross-account
  azs             = var.zone_ids
  private_subnets = var.private_subnet_cidr
  public_subnets  = var.public_subnet_cidr

  enable_nat_gateway            = true
  map_public_ip_on_launch       = true
  private_dedicated_network_acl = true
  private_inbound_acl_rules     = var.private_nacl_inbound_rules
  private_outbound_acl_rules    = var.private_nacl_outbound_rules
  public_dedicated_network_acl  = true
  public_inbound_acl_rules      = var.public_nacl_inbound_rules
  public_outbound_acl_rules     = var.public_nacl_outbound_rules

  tags = {
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}

# Web Server security group with dynamic rules association from object variable
resource "aws_security_group" "sg_web_server" {
  name   = "sg_web_server"
  vpc_id = module.network-vpc.vpc_id
  dynamic "ingress" {
    for_each = var.web_server_sg_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  dynamic "egress" {
    for_each = var.web_server_sg_egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
  lifecycle {
    create_before_destroy = true
    # prevent_destroy = true
  }
  tags = {
    Name = "sg-web-server"
  }
}

resource "aws_security_group" "sg_database_server" {
  name   = "sg_database_server"
  vpc_id = module.network-vpc.vpc_id
  tags = {
    Name = "sg-database-server"
  }
  ingress {
    description     = "Port 3306 from public subnet EC2 instances"
    from_port       = "3306"
    to_port         = "3306"
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web_server.id]
    # cidr_blocks = var.public_subnet_cidr
  }
  egress {
    description = "Access to internet - egress only (stateful)"
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}


module "autoscaling_web_server" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.4.0"

  # Autoscaling group
  name = "${var.environment}-${var.app_identifier}-asg-web-server"

  vpc_zone_identifier = module.network-vpc.public_subnets
  min_size            = 0
  max_size            = var.instance_replica_count
  desired_capacity    = var.instance_replica_count

  security_groups = [aws_security_group.sg_web_server.id]
  # launch template
  launch_template_name        = "${var.app_identifier}-web-server"
  launch_template_description = "Launch template for web servers for app ${var.app_identifier}"
  update_default_version      = true

  image_id = data.aws_ami.ubuntu_2204_latest.id
  # Instance Type set to t2.micro if env==prod and t2.nano if not prod
  # instance_type = var.environment == "prod" ? "t2.micro" : "t2.nano"
  instance_type = var.instance_type_web_server
  tags = {
    Terraform   = "true"
    Service     = var.app_identifier
    Environment = var.environment
  }
}

module "autoscaling_db_server" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.4.0"

  # Autoscaling group
  name = "${var.environment}-${var.app_identifier}-asg-db-server"

  vpc_zone_identifier = module.network-vpc.public_subnets
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1

  security_groups = [aws_security_group.sg_database_server.id]
  # launch template
  launch_template_name        = "${var.app_identifier}-db-server"
  launch_template_description = "Launch template for db servers for app ${var.app_identifier}"
  update_default_version      = true

  image_id = data.aws_ami.ubuntu_2204_latest.id
  # Instance Type set to t2.micro if env==prod and t2.nano if not prod
  # instance_type = var.environment == "prod" ? var.instance_type_prod_db : var.instance_type_qa_db
  instance_type = var.instance_type_db_server
  tags = {
    Terraform   = "true"
    Service     = var.app_identifier
    Environment = var.environment
  }
}