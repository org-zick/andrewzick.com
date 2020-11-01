/* VPC and Security Groups */
resource "aws_vpc" "pw-vpc" {
  cidr_block = "10.0.0.0/23"
}

resource "aws_security_group" "pw-sg-allow-ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.pw-vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "TCP"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  # ALLOW ALL egress rule
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

resource "aws_security_group" "pw-sg-allow-web-traffic" {
  name   = "allow-web-traffic"
  vpc_id = aws_vpc.pw-vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "TCP"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "TCP"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  # ALLOW ALL egress rule
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

/* 1 public subnet, /26 */
resource "aws_subnet" "pw-public-subnet" {
  vpc_id            = aws_vpc.pw-vpc.id
  cidr_block        = "10.0.0.0/26"
  availability_zone = "us-east-1a"
}

/* IGW so that the public subnet is reachable from the internet */
resource "aws_internet_gateway" "pw-internet-gateway" {
  vpc_id = aws_vpc.pw-vpc.id
}

resource "aws_route_table" "pw-route-table" {
  vpc_id = aws_vpc.pw-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pw-internet-gateway.id
  }
}

resource "aws_route_table_association" "pw-public-route-table-assoc" {
  subnet_id      = aws_subnet.pw-public-subnet.id
  route_table_id = aws_route_table.pw-route-table.id
}

/* NLB for the public subnet, forwards ports 80 and 443 to the VPC */
resource "aws_lb" "pw-nlb" {
  name               = "pw-nlb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.pw-public-subnet.id
    allocation_id = aws_eip.pw-nlb-eip.id
  }

  enable_deletion_protection = true
}

# Public IP for the NLB
resource "aws_eip" "pw-nlb-eip" {
  vpc      = true

  # Recommended setting by terraform docs
  depends_on = [aws_internet_gateway.pw-internet-gateway]
}

# Note: It takes a little time for the EC2 to get registered in the target group
resource "aws_lb_target_group" "pw-nlb-target-group-port-80" {
  name     = "pw-nlb-target-group-port-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.pw-vpc.id

  # https://stackoverflow.com/a/60080801/2521402
  # Add lifecycle to help with changes, but might still need to rename every time
  # Might have to rename the listeners as well, so that they create and destroy
  lifecycle {
    create_before_destroy = true
  }

  health_check {
    protocol = "HTTP"
    port = 80
  }
}

resource "aws_lb_target_group" "pw-nlb-target-group-port-443" {
  name     = "pw-nlb-target-group-port-443"
  port     = 443
  protocol = "TCP"
  vpc_id   = aws_vpc.pw-vpc.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    protocol = "HTTP"
    port = 80 # Produces a bunch of error logs if set to HTTPS and 443
  }
}

resource "aws_lb_listener" "pw-nlb-listener-port-80" {
  load_balancer_arn = aws_lb.pw-nlb.arn
  port              = "80"
  protocol          = "TCP" # listeners that are attached to Network Load Balancers must use the TCP protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pw-nlb-target-group-port-80.arn
  }
}

resource "aws_lb_listener" "pw-nlb-listener-port-443" {
  load_balancer_arn = aws_lb.pw-nlb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pw-nlb-target-group-port-443.arn
  }
}
