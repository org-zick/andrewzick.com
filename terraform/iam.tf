resource "aws_iam_role" "personal-website-task-role" {
  name = "personal-website-task-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "personal-website-task-policy" {
  name  = "personal-website-task-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "personal-website-task-policy-attachment" {
  role       = aws_iam_role.personal-website-task-role.name
  policy_arn = aws_iam_policy.personal-website-task-policy.arn
}

# From here: https://gist.githubusercontent.com/paweldudzinski/c536455fa8f1d74ffc9bce9f1396a6a9/raw/1a8c86e4cd4fd9e5e8008c04d23d21da0a29697e/iam.tf
# These four parts are necessary to allow the EC2 to work with ECS
data "aws_iam_policy_document" "ecs-agent-policy-document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs-agent-role" {
  name               = "ecs-agent-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-agent-policy-document.json
}

resource "aws_iam_role_policy_attachment" "ecs-agent-policy-attachment" {
  role       = aws_iam_role.ecs-agent-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm-policy" {
  role       = aws_iam_role.ecs-agent-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs-agent-profile" {
  name = "ecs-agent-profile"
  role = aws_iam_role.ecs-agent-role.name
}
