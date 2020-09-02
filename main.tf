data "external" "external-ip" {
  program = ["./get-external-ip.sh"]
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
  security_groups      = ["${aws_security_group.mern-stack-sg.name}"]

  tags = {
    Name = "mern_stack_instance"
  }

  user_data = file("./pull-app-image.sh")
}

output "ssh" {
  value = "ssh ec2-user@${aws_instance.mern-stack-server.public_ip}"
}

resource "aws_eip" "mern-stack-assigned-ip" {
  instance = aws_instance.mern-stack-server.id
  vpc      = true
}

resource "aws_security_group" "mern-stack-sg" {
  name        = "mern-stack-sg"
  description = "Security group for mern-stack"
}

resource "aws_security_group_rule" "allow-traffic-from-tbrandon" {
  security_group_id = aws_security_group.mern-stack-sg.id
  type = "ingress"

  description = "All traffic from tbrandon"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["80.6.232.161/32"]
}

resource "aws_security_group_rule" "allow-traffic-from-current-host" {
  security_group_id = aws_security_group.mern-stack-sg.id
  type = "ingress"

  description = "All traffic from current machine"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["${data.external.external-ip.result.ip}/32"]
}

resource "aws_security_group_rule" "allow-all-egress" {
  security_group_id = aws_security_group.mern-stack-sg.id
  type = "egress"

  description = "Allow all egress traffic"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
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


