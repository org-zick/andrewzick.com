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
    protocol = "TCP"
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
    protocol = "TCP"
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
