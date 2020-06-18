resource "aws_key_pair" "aws-ec2-ssh-key-pair" {
  key_name   = "aws-ec2-ssh-key-pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCpUslKoi+m+7Vj1ks+vc83KaQkb7XQc2i+OVC7S0ZpyWs0B201p+GbTenRbqjmkY5fGaZ/4XRiwXHwtn17D3wLaf5LtibL0kTKDJLrFEvdof0Q/TMPRaSE62yeY4zrJ1X6iUqEPe6gPql1jHjco0Yjz1iM0suok1IMLV/OlSWiCSA52HMYikvCRuq3P7XPPv/WKbpBZfXHT37z9atwcTjTAKueIRTBthQdMU0Ntetas0h48XXxBEJHxB0niq9cAIvcffTDJbmRoDnLPFySsa/RNLgmYlEwjxqwfzSA+yTwErF1Vl3OUw/0YF7TXcI7u7FQH/8NIeKmnuMLaNm112v5 andrewzick@gmail.com"
}

data "aws_ami" "ubuntu_20-04_LTS_ami" {
  most_recent = true
  owners      = ["099720109477"] # Ubuntu

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "caddy-test-ec2-instance" {
  ami                         = data.aws_ami.ubuntu_20-04_LTS_ami.id
  instance_type               = "t3a.micro"
  key_name                    = aws_key_pair.aws-ec2-ssh-key-pair.id
  subnet_id                   = aws_subnet.pw-public-subnet.id
  vpc_security_group_ids      = [aws_security_group.pw-sg-allow-ssh.id, aws_security_group.pw-sg-allow-web-traffic.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "standard"
    volume_size           = 10
    delete_on_termination = true
    encrypted             = true
  }
}