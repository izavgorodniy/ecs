provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 1.1.8"
}

resource "aws_key_pair" "admin" {
  key_name   = "admin-key"
  public_key = file(var.ssh_pubkey_file)
}

####################################
# VPC
####################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "Terraform VPC"
  }
}

####################################
# IAM
####################################

resource "aws_iam_role" "ecs_host_role" {
  name               = "ecs_host_role"
  assume_role_policy = file("policies/ecs-role.json")
}

resource "aws_iam_role_policy" "ecs_instance_role_policy" {
  name   = "ecs_instance_role_policy"
  policy = file("policies/ecs-instance-role-policy.json")
  role   = aws_iam_role.ecs_host_role.id
}

resource "aws_iam_role" "ecs_service_role" {
  name               = "ecs_service_role"
  assume_role_policy = file("policies/ecs-role.json")
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs_service_role_policy"
  policy = file("policies/ecs-service-role-policy.json")
  role   = aws_iam_role.ecs_service_role.id
}

resource "aws_iam_instance_profile" "ecs" {
  name = "ecs-instance-profile"
  path = "/"
  role = aws_iam_role.ecs_host_role.name
}

####################################
# SUBNETS PUBLIC
####################################

# Create Public Subnet1
resource "aws_subnet" "pub_sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet1"
  }
}
# Create Public Subnet2 
resource "aws_subnet" "pub_sub2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet2"
  }
}

####################################
# SUBNETS PRIVATE
####################################

# Create Private Subnet1
resource "aws_subnet" "prv_sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.7.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private_subnet1"
  }
}
# Create Private Subnet2
resource "aws_subnet" "prv_sub2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.8.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private_subnet2"
  }
}

####################################
# ROUTE TABLE 2
####################################

# Create Public Route Table
resource "aws_route_table" "pub_sub1_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public subnet route table"
  }
}
# Create route table association of public subnet1
resource "aws_route_table_association" "internet_for_pub_sub1" {
  route_table_id = aws_route_table.pub_sub1_rt.id
  subnet_id      = aws_subnet.pub_sub1.id
}
# Create route table association of public subnet2
resource "aws_route_table_association" "internet_for_pub_sub2" {
  route_table_id = aws_route_table.pub_sub1_rt.id
  subnet_id      = aws_subnet.pub_sub2.id
}

####################################
# INERNET GATEWAY 2
####################################


# Create Internet Gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {

    Name = "internet gateway"
  }
}

####################################
# EIP and NAT
####################################

# Create EIP for NAT GW1  
resource "aws_eip" "eip_natgw1" {
  count = "1"
}
# Create NAT gateway1
resource "aws_nat_gateway" "natgateway_1" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw1[count.index].id
  subnet_id     = aws_subnet.pub_sub1.id
}
# Create EIP for NAT GW2 
resource "aws_eip" "eip_natgw2" {
  count = "1"
}
# Create NAT gateway2 
resource "aws_nat_gateway" "natgateway_2" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw2[count.index].id
  subnet_id     = aws_subnet.pub_sub2.id
}


####################################
# Route tables for private subnets
####################################

# Create private route table for prv sub1
resource "aws_route_table" "prv_sub1_rt" {
  count  = "1"
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_1[count.index].id
  }
  tags = {
    Name = "private subnet1 route table"
  }
}
# Create route table association betn prv sub1 & NAT GW1
resource "aws_route_table_association" "pri_sub1_to_natgw1" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub1_rt[count.index].id
  subnet_id      = aws_subnet.prv_sub1.id
}
# Create private route table for prv sub2
resource "aws_route_table" "prv_sub2_rt" {
  count  = "1"
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_2[count.index].id
  }
  tags = {
    Name = "private subnet2 route table"
  }
}
# Create route table association betn prv sub2 & NAT GW2
resource "aws_route_table_association" "pri_sub2_to_natgw1" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub2_rt[count.index].id
  subnet_id      = aws_subnet.prv_sub2.id
}

####################################
# security groups for Application load balancer and ecs.
####################################

# Create security group for load balancer
resource "aws_security_group" "elb_sg" {
  name        = var.sg_name
  description = var.sg_description
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.sg_tagname
  }
}
# Create security group for ecs
resource "aws_security_group" "ecs_sg" {
  name        = var.sg_ws_name
  description = var.sg_ws_description
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = var.sg_ws_tagname
  }
}

####################################
# TARGET GROUP
####################################

# Create Target group
resource "aws_lb_target_group" "TG-tf" {
  name       = "TargetGroup-tf"
  depends_on = [aws_vpc.main]
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.main.id
  health_check {
    interval            = 70
    path                = "/"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 60
    protocol            = "HTTP"
    matcher             = "200,202"
  }
}

####################################
# LOAD BALANCER & LISTENER
####################################

# Create ALB
resource "aws_lb" "ALB-tf" {
  name               = "ALB-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = [aws_subnet.pub_sub1.id, aws_subnet.pub_sub2.id]
  tags = {
    name = "AppLoadBalancer-tf"
  }
}
# Create ALB Listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ALB-tf.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TG-tf.arn
  }
}

####################################
# Launch config
####################################

#Create Launch config
resource "aws_launch_configuration" "ecs-launch-config" {
  name                 = "ECS ${var.ecs_cluster_name}"
  image_id        = lookup(var.amis, var.region)
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.admin.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs.name
  security_groups = ["${aws_security_group.elb_sg.id}"]

  lifecycle {
    create_before_destroy = true
  }
  user_data = "#!/bin/bash\necho ECS_CLUSTER=us-app >> /etc/ecs/ecs.config"
}

####################################
# Auto Scaling Group
####################################

# Create Auto Scaling Group
resource "aws_autoscaling_group" "ASG-tf" {
  name                 = "ASG-tf"
  desired_capacity     = 2
  max_size             = 5
  min_size             = 1
  force_delete         = true
  depends_on           = [aws_lb.ALB-tf]
  target_group_arns    = ["${aws_lb_target_group.TG-tf.arn}"]
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.ecs-launch-config.name
  vpc_zone_identifier  = ["${aws_subnet.prv_sub1.id}", "${aws_subnet.prv_sub2.id}"]

  tag {
    key                 = "Name"
    value               = "ASG-tf"
    propagate_at_launch = true
  }
}

####################################
# ECS
####################################

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.ecs_cluster_name}-app"
}

####################################
# ECS SERVICE
####################################

resource "aws_ecs_task_definition" "us-http" {
  family                = "us-http"
  container_definitions = file("td.json")
}

resource "aws_ecs_service" "us-http" {
  name            = "us-http"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.us-http.arn
  iam_role        = aws_iam_role.ecs_service_role.arn
  desired_count   = 2
  depends_on      = [aws_iam_role_policy.ecs_service_role_policy]

  load_balancer {
    target_group_arn = aws_lb_target_group.TG-tf.arn
    container_name   = "nginx"
    container_port   = 80
  }
}

output "alb_dns" {
  value = aws_lb.ALB-tf.dns_name
}