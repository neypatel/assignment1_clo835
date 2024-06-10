provider "aws" {
  region = "us-east-1"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_account_id" {
  default = "309676119673"
}

resource "aws_ecr_repository" "webapp" {
  name = "webapp"
}

resource "aws_ecr_repository" "mysql" {
  name = "mysql"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "my_security_group" {
  name        = "my_security_group"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_instance" {
  count                  = 3
  ami                    = "ami-0d191299f2822b1fa" # Amazon Linux 2 AMI
  instance_type          = "t2.micro"
  key_name               = "my-key" # Update with your key pair name
  subnet_id              = "subnet-01e9abed8c8c24db7"  # Replace with your subnet ID
  vpc_security_group_ids = ["sg-0f841e3f2d6b6e1e7"]
  associate_public_ip_address = true
  
  user_data = <<-EOF
    #!/bin/bash
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user

    docker login -u AWS -p $(aws ecr get-login-password --region ${var.aws_region}) ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    docker network create app-network

    docker run --name webapp --network app-network -e COLOR=${count.index} -p 808${count.index+1}:8080 ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/webapp:latest

    docker run --name mysql --network app-network -e MYSQL_ROOT_PASSWORD=rootpassword -e MYSQL_DATABASE=webapp -d ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/mysql:latest
  EOF

  tags = {
    Name = "my-instance"
  }
}
