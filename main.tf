variable "key_pair" {
  type = string
  default = "mern-stack"
}

provider "aws" {
  # IMHO, when possible, the 'terraform script' should be agnostic from any 'environment setup'
  # that increase 'portability' and push the responsibility of 'configuring the AWS access' to the
  # operator who run the scripts
  # profile = "tombrandon"
  region  = "eu-west-1"
}

resource "aws_instance" "mern-stack-server" {
  ami                  = "ami-07d9160fa81ccffb5" # Amazon Linux 2
  instance_type        = "t2.micro"
  iam_instance_profile = "mern-stack" #FIXME: this should be terraformed
  security_groups      = ["mern-stack-sg"] #FIXME: this should rather be a reference to the resource created further below
  key_name             = var.key_pair #FIXME: if we choose to not manage the key pair in this terraform, then we should probably make this configurable via a variable

  tags = {
    Name = "mern_stack_instance"
  }

  user_data = file("./pull-app-image.sh")
}

#TODO: for convenience, add some 'output' that display the 'ssh command' to be used
output "ssh" {
  value = "ssh -i ~/.ssh/${var.key_pair} ec2-user@${aws_instance.mern-stack-server.public_ip}"
}

resource "aws_eip" "mern-stack-assigned-ip" {
  instance = aws_instance.mern-stack-server.id
  vpc      = true
}

resource "aws_security_group" "mern-stack-sg" {
  name        = "mern-stack-sg"
  description = "Allow inbound traffic"

  ingress {
    description = "All TCP from own sg"
    from_port   = 0
    to_port     = 65535
    protocol    = "TCP"
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
}

resource "aws_lb" "mern-stack-lb" {
  name               = "mern-stack-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mern-stack-lb-sg.id]
  subnets            = ["subnet-35b03b6f", "subnet-1095cc58", "subnet-3cffb15a"]
}

resource "aws_security_group" "mern-stack-lb-sg" {
  name        = "mern-stack-lb-sg"
  description = "load balancer security group terraformed"

  ingress {
    description = "All HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "egress-from-lb-sg-to-mern-sg" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = -1
  security_group_id        = aws_security_group.mern-stack-lb-sg.id
  source_security_group_id = aws_security_group.mern-stack-sg.id

  depends_on = [
    aws_security_group.mern-stack-sg,
    aws_security_group.mern-stack-lb-sg
  ]
}

resource "aws_security_group_rule" "ingress-to-mern-sg-from-lb-sg" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  security_group_id        = aws_security_group.mern-stack-sg.id
  source_security_group_id = aws_security_group.mern-stack-lb-sg.id

  depends_on = [
    aws_security_group.mern-stack-sg,
    aws_security_group.mern-stack-lb-sg
  ]
}


resource "aws_lb_listener" "front-end-mern-stack-http" {
  load_balancer_arn = aws_lb.mern-stack-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    target_group_arn = aws_lb_target_group.mern-stack-lb-target.arn

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

data "aws_acm_certificate" "trainbrain" {
  domain   = "test.t.useyourbra.in"
  statuses = ["ISSUED"]
}


resource "aws_lb_listener" "front-end-mern-stack-https" {
  load_balancer_arn = aws_lb.mern-stack-lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.trainbrain.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mern-stack-lb-target.arn

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "mern-stack-lb-target" {
  name     = "mern-stack-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-34120e52"
}

resource "aws_lb_target_group_attachment" "mern-stack-lb-tg-attach" {
  target_group_arn = aws_lb_target_group.mern-stack-lb-target.arn
  target_id        = aws_instance.mern-stack-server.id
  port             = 80
}


