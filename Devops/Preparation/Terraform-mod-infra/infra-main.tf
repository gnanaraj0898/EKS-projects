# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "5.0"
#     }
#   }
# }



# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

#creating IP address for NAT
resource "aws_eip" "eips" {
  count = 2

  domain = "vpc"
  depends_on = [ aws_vpc.tera-vpc ]
}

################################################################################
# VPC 
################################################################################

resource "aws_vpc" "tera-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tera-vpc"
  }
}
################################################################################
# Subnet
################################################################################

resource "aws_subnet" "tera-public-subnet1" {
  vpc_id     = aws_vpc.tera-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  

  tags = {
    Name = "tera-public-subnet1"
  }
}
resource "aws_subnet" "tera-public-subnet2" {
  vpc_id     = aws_vpc.tera-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
 

  tags = {
    Name = "tera-public-subnet2"
  }
}
resource "aws_subnet" "tera-private-subnet1" {
  vpc_id     = aws_vpc.tera-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-west-2a"
  

  tags = {
    Name = "tera-private-subnet1"
  }
}
resource "aws_subnet" "tera-private-subnet2" {
  vpc_id     = aws_vpc.tera-vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-west-2b"
  

  tags = {
    Name = "tera-private-subnet2"
  }
}
################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tera-vpc.id

  tags = {
    Name = "tera-igw"
  }
}

################################################################################
# NAT Gateway
################################################################################
resource "aws_nat_gateway" "NAT1" {
  allocation_id = aws_eip.eips[0].id
  subnet_id     = aws_subnet.tera-public-subnet1.id

  tags = {
    Name = "tera-NAT1"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "NAT2" {
  allocation_id = aws_eip.eips[1].id
  subnet_id     = aws_subnet.tera-public-subnet2.id

  tags = {
    Name = "tera-NAT2"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}
################################################################################
# Route table
################################################################################
resource "aws_route_table" "tera-public-RT" {
  vpc_id = aws_vpc.tera-vpc.id

  route {
    cidr_block = aws_vpc.tera-vpc.cidr_block
    gateway_id = "local"
  }
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "tera-public-RT"
  }
}
resource "aws_route_table" "tera-private-RT1" {
  vpc_id = aws_vpc.tera-vpc.id

  route {
    cidr_block = aws_vpc.tera-vpc.cidr_block
    gateway_id = "local"
  }
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT1.id
  }
  tags = {
    Name = "tera-private-RT1"
  }
}
resource "aws_route_table" "tera-private-RT2" {
  vpc_id = aws_vpc.tera-vpc.id

  route {
    cidr_block = aws_vpc.tera-vpc.cidr_block
    gateway_id = "local"
  }
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT2.id
  }
  tags = {
    Name = "tera-private-RT2"
  }
}
################################################################################
# Route table Association
################################################################################
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.tera-public-subnet1.id
  route_table_id = aws_route_table.tera-public-RT.id
}
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.tera-public-subnet2.id
  route_table_id = aws_route_table.tera-public-RT.id
}
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.tera-private-subnet1.id
  route_table_id = aws_route_table.tera-private-RT1.id
}
resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.tera-private-subnet2.id
  route_table_id = aws_route_table.tera-private-RT2.id
}

################################################################################
# Security Groups 1
################################################################################
resource "aws_security_group" "server-sg" {
  name        = "server-sg"
  description = "Allow TLS inbound traffic and all outbound traffic sg1"
  vpc_id      = aws_vpc.tera-vpc.id

  tags = {
    Name = "server-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4-sg1" {
  security_group_id = aws_security_group.server-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_security_group_rule" "allow_ssh_ipv4-sg1" {

  source_security_group_id = aws_security_group.Bastion-public-sg.id
  type = "ingress"
  from_port         = 22
  protocol       = "tcp"
  to_port           = 22
  security_group_id = aws_security_group.server-sg.id

  #cidr_ipv4 = source.security_group_id
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4-sg1" {
  security_group_id = aws_security_group.server-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

################################################################################
# Security Groups 2
################################################################################
resource "aws_security_group" "Bastion-public-sg" {
  name        = "server-sg2"
  description = "Allow TLS inbound traffic and all outbound traffic sg2"
  vpc_id      = aws_vpc.tera-vpc.id

  tags = {
    Name = "Bastion-public-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4-sg2" {
  security_group_id = aws_security_group.Bastion-public-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4-sg2" {
  security_group_id = aws_security_group.Bastion-public-sg.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  cidr_ipv4 = "0.0.0.0/0"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4-sg2" {
  security_group_id = aws_security_group.Bastion-public-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


################################################################################
# Launch Template
################################################################################
resource "aws_launch_template" "LT" {
  name = "LT1"
  image_id = "ami-02d3770deb1c746ec"
  instance_type = "t2.micro"
  key_name = "Terraform-infra-key"
  vpc_security_group_ids = [aws_security_group.server-sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "tera-LT"
    }
  }
  user_data = filebase64("${path.module}/web.sh")
}
################################################################################
# Auto Scaling group
################################################################################
resource "aws_autoscaling_group" "tera-asg" {
  vpc_zone_identifier = [ aws_subnet.tera-private-subnet1.id, aws_subnet.tera-private-subnet2.id ]
  #availability_zones = ["us-west-2a"]
  desired_capacity   = 2
  max_size           = 4
  min_size           = 1

  launch_template {
    id      = aws_launch_template.LT.id
    version = "$Latest"
  }
  target_group_arns = [ aws_lb_target_group.tera-TG.arn ]
}
################################################################################
# Target group & Load balancing
################################################################################
resource "aws_lb_target_group" "tera-TG" {
  name     = "tera-TG"
  port     = 80
  protocol = "HTTP"
  ip_address_type = "ipv4"
  vpc_id   = aws_vpc.tera-vpc.id
  target_type = "instance"
}

resource "aws_lb" "tera-lb" {
  name               = "tera-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Bastion-public-sg.id]
  subnets            = [aws_subnet.tera-public-subnet1.id, aws_subnet.tera-public-subnet2.id]

  tags = {
    Environment = "production"
  }
}
resource "aws_lb_listener" "tera-listener" {
  load_balancer_arn = aws_lb.tera-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tera-TG.arn
  }
}