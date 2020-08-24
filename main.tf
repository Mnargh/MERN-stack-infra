
provider "aws" {
  profile = "tombrandon"
  region  = "eu-west-1"
}

resource "aws_instance" "mern-stack-server" {
  ami                  = "ami-07d9160fa81ccffb5"
  instance_type        = "t2.micro"
  iam_instance_profile = "mern-stack"
  security_groups      = ["mern-stack-sg"]
  tags = {
    Name = "mern-stack-instance"
  }
}

resource "aws_security_group" "mern-stack-sg" {
  name        = "mern-stack-sg"
  description = "Allow inbound traffic"

  ingress {
    description = "All TCP from mern-stack-sg"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "All traffic from Laptop"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["80.6.232.161/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mern-stack"
  }
}
