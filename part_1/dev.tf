provider "aws" {
region = "eu-central-1"
}
#---vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "my-vpc"
  cidr = "10.0.0.0/16"
  azs             = ["eu-central-1a", "eu-central-1b"]
  #private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  #enable_nat_gateway = true
  #enable_vpn_gateway = true
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
#---sg
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow 80 inbound traffic"
  vpc_id      = module.vpc.vpc_id 
  ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_http"
  }
}
#---ec2
resource "aws_instance" "instance1" {
#  ami                         = "ami-07fc7611503eb6b29" #win2019sr
  ami                         = "ami-0d51a78a0a50b60e1" #ami linux
  availability_zone           = module.vpc.azs[0]
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  user_data = file("udata.sh")		
  tags = {
    "Owner"               = "danyliuk"
    "Name"                = "web-server-1"
    "KeepInstanceRunning" = "false"
  }
}
resource "aws_instance" "instance2" {
#  ami                         = "ami-07fc7611503eb6b29" #win2019sr
  ami                         = "ami-0d51a78a0a50b60e1" #ami linux
  availability_zone           = module.vpc.azs[1]
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id = module.vpc.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  user_data = file("udata.sh")	
  tags = {
    "Owner"               = "danyliuk"
    "Name"                = "web-server-2"
    "KeepInstanceRunning" = "false"
  }
}

#---nlb
resource "aws_lb" "test" {
  name               = "my-lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets[*]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection = false
  tags = {
    Environment = "dev"
  }
}
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-tg.arn
  }
}
resource "aws_lb_target_group" "my-tg" {
  name        = "tf-example-lb-tg"
  port        = 80
  protocol    = "TCP"
  #target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  target_type      = "instance"
}
resource "aws_lb_target_group_attachment" "my-tg1" {
  target_group_arn = aws_lb_target_group.my-tg.arn
  target_id        = aws_instance.instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "my-tg2" {
  target_group_arn = aws_lb_target_group.my-tg.arn
  target_id        = aws_instance.instance2.id
  port             = 80
}