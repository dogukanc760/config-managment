terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_key_pair" "config_manager" {
  key_name   = "config-manager"
  public_key = file("${path.module}/../roles/ssh/files/config-manager.pub")
}

resource "aws_security_group" "config_manager" {
  name        = "config-manager-sg"
  description = "Allow SSH and HTTP/HTTPS"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "config-manager-sg"
  }
}

resource "aws_instance" "config_manager" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.config_manager.key_name
  vpc_security_group_ids = [aws_security_group.config_manager.id]

  tags = {
    Name = "config-manager"
  }
}
