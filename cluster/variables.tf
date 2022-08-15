variable "service_name" {
  default = "app"
}


variable "region" {
  default = "us-east-1"
}

variable "availability_zone" {
  default = "us-east-1b"
}

variable "ecs_cluster_name" {
  default = "us"
}

variable "infra_type" {
  default = "ecs"
}

variable "autoscale_min" {
  default = "1"
}

variable "autoscale_max" {
  default = "5"
}

variable "autoscale_desired" {
  default = "2"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "amis" {
  description = "Which AMI to spawn. Defaults to the AWS ECS optimized images."
  # TODO: support other regions.
  default = {
    us-east-1 = "ami-00129b193dc81bc31"
  }
}

variable "ssh_pubkey_file" {
  description = "Path to an SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "deregistration_delay" {
  default = 30
}


variable "health_check_path" {
  default     = "/"
  description = "The default health check path"
}


variable "name" {
  description = "Name of the subnet, actual name will be, for example: name_eu-west-1a"
  default     = "name_eu-west-1a"
}

variable "environment" {
  description = "The name of the environment"
  default     = "test"
}

###############

variable "sg_name" {
  type    = string
  default = "alb_sg"
}

variable "sg_description" {
  type    = string
  default = "SG for application load balancer"
}

variable "sg_tagname" {
  type    = string
  default = "SG for ALB"
}

variable "sg_ws_name" {
  type    = string
  default = "ecs_sg"
}

variable "sg_ws_description" {
  type    = string
  default = "SG for ECS"
}

variable "sg_ws_tagname" {
  type    = string
  default = "SG for ECS"
}