### This module deploys a network with:
# 1 core VPC and 2 subnets in 1 AZ
# 1 public subnets + 1 private subnets
# + number of web server instances (according to environment) and one db server
# + Security groups + NACLs + Route Tables

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

# Deploy main VPC
resource "aws_vpc" "core_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name      = "${var.environment}-vpc-${local.region}"
    Terraform = "true"
  }
}
# Deploy subnets
resource "aws_subnet" "public_subnet01" {
  vpc_id                  = aws_vpc.core_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone_id    = var.zone_ids[0]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-public-${var.zone_ids[0]}"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}
resource "aws_subnet" "private_subnet01" {
  vpc_id               = aws_vpc.core_vpc.id
  cidr_block           = var.private_subnet_cidr
  availability_zone_id = var.zone_ids[0]
  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-private-${var.zone_ids[0]}"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}

# Deploy Internet Gateway
resource "aws_internet_gateway" "core_vpc_igw" {
  vpc_id = aws_vpc.core_vpc.id
  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-igw"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}

# Deploy EIP for NAT Gateway
resource "aws_eip" "nat_gw_eip" {
  domain = "vpc"
  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-nat-eip"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}

# Deploy NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw_eip.allocation_id
  subnet_id     = aws_subnet.public_subnet01.id

  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-nat"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}

# Public Route Table
resource "aws_route_table" "public_subnet01_rt" {
  vpc_id = aws_vpc.core_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.core_vpc_igw.id
  }

  tags = {
    Name = "${aws_vpc.core_vpc.tags.Name}-public-${var.zone_ids[0]}-routeTable"
  }
}
# Private Route Table
resource "aws_route_table" "private_subnet01_rt" {
  vpc_id = aws_vpc.core_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${aws_vpc.core_vpc.tags.Name}-private-${var.zone_ids[0]}-routeTable"
  }
}

# Route Tables association to subnets
resource "aws_route_table_association" "public_subnet01_rt_association" {
  subnet_id      = aws_subnet.public_subnet01.id
  route_table_id = aws_route_table.public_subnet01_rt.id
}
resource "aws_route_table_association" "private_subnet01_rt_association" {
  subnet_id      = aws_subnet.private_subnet01.id
  route_table_id = aws_route_table.private_subnet01_rt.id
}


# Deploy NACLs
resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.core_vpc.id
  subnet_ids = [aws_subnet.public_subnet01.id]
  # Allow IN HTTPS traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 98
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  # Allow IN HTTP traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 99
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # Allow IN traffic for user/server applications & clients
  # + Allow IN all traffic from AWS internal network
  dynamic "ingress" {
    for_each = var.common_nacl_ingress_rules
    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.common_nacl_egress_rules
    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }
  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-${local.region}-public-nacl"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.core_vpc.id
  subnet_ids = [aws_subnet.private_subnet01.id]
  dynamic "ingress" {
    for_each = var.common_nacl_ingress_rules
    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.common_nacl_egress_rules
    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }
  tags = {
    Name        = "${aws_vpc.core_vpc.tags.Name}-${local.region}-private-nacl"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}
# Web Server security group with dynamic rules association from object variable
resource "aws_security_group" "sg_web_server" {
  name   = "sg_web_server"
  vpc_id = aws_vpc.core_vpc.id
  dynamic "ingress" {
    for_each = var.web_server_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  dynamic "egress" {
    for_each = var.web_server_egress_rules
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
    Name        = "sg-web-server"
    Terraform   = "true"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "sg_database_server" {
  name   = "sg_database_server"
  vpc_id = aws_vpc.core_vpc.id
  tags = {
    Name        = "sg-database-server"
    Terraform   = "true"
    Environment = "${var.environment}"
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

resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu_2204_latest.id
  instance_type               = var.instance_type_web_server
  count                       = var.instance_replica_count
  subnet_id                   = aws_subnet.public_subnet01.id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.sg_web_server.id]
  tags = {
    Name        = "${var.environment}-${var.app_identifier}-web-server"
    Terraform   = "true"
    Service     = var.app_identifier
    Environment = var.environment
  }
}

resource "aws_instance" "db_server" {
  ami                         = data.aws_ami.ubuntu_2204_latest.id
  instance_type               = var.instance_type_db_server
  subnet_id                   = aws_subnet.private_subnet01.id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.sg_database_server.id]
  tags = {
    Name        = "${var.environment}-${var.app_identifier}-db-server"
    Terraform   = "true"
    Service     = var.app_identifier
    Environment = var.environment
  }
}