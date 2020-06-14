resource "aws_vpc" "pw-vpc" {
  cidr_block = "10.0.0.0/23"
}

resource "aws_security_group" "pw-sg-allow-ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.pw-vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

resource "aws_subnet" "pw-public-subnet" {
  vpc_id            = aws_vpc.pw-vpc.id
  cidr_block        = "10.0.0.0/26"
  availability_zone = "us-east-1a"
}

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