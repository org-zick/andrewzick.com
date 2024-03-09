/* VPC and Security Groups */
resource "aws_vpc" "pw-vpc" {
  cidr_block = "10.0.0.0/23"
  # assign_generated_ipv6_cidr_block = true
}

resource "aws_security_group" "pw-sg-allow-ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.pw-vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # ALLOW ALL egress rule
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "pw-sg-allow-web-traffic" {
  name   = "allow-web-traffic"
  vpc_id = aws_vpc.pw-vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # ALLOW ALL egress rule
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

/* 1 public subnet, /26 */
resource "aws_subnet" "pw-public-subnet" {
  vpc_id                  = aws_vpc.pw-vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
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

  # route {
  #   ipv6_cidr_block = "::/0"
  #   gateway_id = "${aws_internet_gateway.pw-internet-gateway.id}"
  # }
}

resource "aws_route_table_association" "pw-public-route-table-assoc" {
  subnet_id      = aws_subnet.pw-public-subnet.id
  route_table_id = aws_route_table.pw-route-table.id
}
