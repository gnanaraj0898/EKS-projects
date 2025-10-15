provider "aws" {
  region = "us-west-2"
}

################################################################################
# Launch Template
################################################################################
resource "aws_launch_template" "LT" {
  name = "LT1"
  image_id = "ami-02d3770deb1c746ec"
  instance_type = "t2.micro"
  key_name = "Terraform-infra-key"
  vpc_security_group_ids = ["sg-03fe964fe08666a03"]
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
  vpc_zone_identifier = [ "subnet-03851bf01507b36a8", "subnet-080b52b814652fbae"]
  #availability_zones = ["us-west-2a"]
  desired_capacity   = 1
  max_size           = 2
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
  vpc_id   = "vpc-04988d6bb727e565d"
  target_type = "instance"
}

resource "aws_lb" "tera-lb" {
  name               = "tera-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-03fe964fe08666a03",]
  subnets            = ["subnet-03851bf01507b36a8", "subnet-080b52b814652fbae"]

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