data "external" "external-ip" {
  program = ["../files/get-external-ip.sh"]
}

provider "aws" {
  # IMHO, when possible, the 'terraform script' should be agnostic from any 'environment setup'
  # that increase 'portability' and push the responsibility of 'configuring the AWS access' to the
  # operator who run the scripts
  # profile = "tombrandon"
  region = "eu-west-1"
}

resource "aws_instance" "mern-stack-server" {
  ami                  = "ami-07d9160fa81ccffb5" # Amazon Linux 2
  instance_type        = "t2.micro"
  iam_instance_profile = "mern-stack" #FIXME: this should be terraformed
  security_groups      = ["${aws_security_group.mern-stack-sg.name}"]

  tags = {
    Name = "mern-stack-instance-${var.env_prefix}"
  }

  user_data = data.template_file.userdata.rendered
}

data "template_file" "userdata" {
  template = file("../files/userdata.sh")
  vars = {
    MONGODB_ACCESS         = "${var.MONGODB_ACCESS}"
    MONGODB_GROUP_ID       = "${var.MONGODB_GROUP_ID}"
    MONGODB_PUBLIC_API_KEY = "${var.MONGODB_PUBLIC_API_KEY}"
    MONGODB_SECRET_API_KEY = "${var.MONGODB_SECRET_API_KEY}"
    JWT_SECRET             = "${var.JWT_SECRET}"
    GITHUB_CLIENT_ID       = "${var.GITHUB_CLIENT_ID}"
    GITHUB_SECRET          = "${var.GITHUB_SECRET}"
    APP_VERSION            = "${var.APP_VERSION}"
  }
}
resource "aws_eip" "mern-stack-assigned-ip" {
  instance = aws_instance.mern-stack-server.id
  vpc      = true
}

output "ssh" {
  value = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_eip.mern-stack-assigned-ip.public_ip}"
}

output "app_version" {
  value = "${var.APP_VERSION}"
}

resource "aws_security_group" "mern-stack-sg" {
  name        = "mern-stack-sg-${var.env_prefix}"
  description = "Security group for mern-stack"
}

resource "aws_security_group_rule" "allow-traffic-from-current-host" {
  security_group_id = aws_security_group.mern-stack-sg.id
  type              = "ingress"

  description = "All traffic from current machine"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["${data.external.external-ip.result.ip}/32"]
}

resource "aws_security_group_rule" "allow-traffic-for-debugging" {
  security_group_id = aws_security_group.mern-stack-sg.id
  type              = "ingress"

  description = "All traffic from current machine"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["86.27.118.138/32"]
}

resource "aws_security_group_rule" "allow-all-egress" {
  security_group_id = aws_security_group.mern-stack-sg.id
  type              = "egress"

  description = "Allow all egress traffic"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "mern-stack-lb" {
  name               = "mern-stack-lb-${var.env_prefix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mern-stack-lb-sg.id]
  subnets            = ["subnet-35b03b6f", "subnet-1095cc58", "subnet-3cffb15a"]
}

resource "aws_security_group" "mern-stack-lb-sg" {
  name        = "mern-stack-lb-sg-${var.env_prefix}"
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
  domain   = "${var.env_prefix}.t.useyourbra.in"
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
  name     = "mern-stack-lb-tg-${var.env_prefix}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-34120e52"
}

resource "aws_lb_target_group_attachment" "mern-stack-lb-tg-attach" {
  target_group_arn = aws_lb_target_group.mern-stack-lb-target.arn
  target_id        = aws_instance.mern-stack-server.id
  port             = 80
}

data "aws_route53_zone" "useyourbrain" {
  name = "t.useyourbra.in."
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.useyourbrain.zone_id
  name    = "${var.env_prefix}.t.useyourbra.in"
  type    = "A"

  alias {
    name                   = aws_lb.mern-stack-lb.dns_name
    zone_id                = aws_lb.mern-stack-lb.zone_id
    evaluate_target_health = false
  }
}

output "web" {
  value = "https://${aws_route53_record.main.fqdn}"
}

