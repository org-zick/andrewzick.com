resource "aws_key_pair" "aws-ec2-ssh-key-pair" {
  key_name   = "aws-ec2-ssh-key-pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCpUslKoi+m+7Vj1ks+vc83KaQkb7XQc2i+OVC7S0ZpyWs0B201p+GbTenRbqjmkY5fGaZ/4XRiwXHwtn17D3wLaf5LtibL0kTKDJLrFEvdof0Q/TMPRaSE62yeY4zrJ1X6iUqEPe6gPql1jHjco0Yjz1iM0suok1IMLV/OlSWiCSA52HMYikvCRuq3P7XPPv/WKbpBZfXHT37z9atwcTjTAKueIRTBthQdMU0Ntetas0h48XXxBEJHxB0niq9cAIvcffTDJbmRoDnLPFySsa/RNLgmYlEwjxqwfzSA+yTwErF1Vl3OUw/0YF7TXcI7u7FQH/8NIeKmnuMLaNm112v5 andrewzick@gmail.com"
}

# Amazon Linux 2
data "aws_ami" "amazon-linux-2023" {
  most_recent = true
  owners      = ["amazon"] # Amazon

  filter {
   name   = "name"
   values = ["al2023-ami-ecs-hvm-*-x86_64"]
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
