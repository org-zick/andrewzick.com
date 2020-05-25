provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_kms_key" "s3-enc-key" {
  description             = "KMS key for encrypting S3 files in ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "tf-state-s3" {
  bucket = "personal-website-tf-state-${var.environment}"
  region = var.region
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3-enc-key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "tf-state-policy" {
  bucket = aws_s3_bucket.tf-state-s3.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Principal":{"AWS":"arn:aws:iam::153765495495:user/andrewzick"},
      "Resource": "${aws_s3_bucket.tf-state-s3.arn}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Principal":{"AWS":"arn:aws:iam::153765495495:user/andrewzick"},
      "Resource": "${aws_s3_bucket.tf-state-s3.arn}/network/terraform.tfstate"
    }
  ]
}
EOF
}

resource "aws_s3_bucket_public_access_block" "tf-state-block-public-access" {
  bucket = aws_s3_bucket.tf-state-s3.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "personal-website-ecr" {
  name                 = "personal-website"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "personal-website-ecr-repo-policy" {
  repository = aws_ecr_repository.personal-website-ecr.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "personal-website ECR access policy",
      "Effect": "Allow",
      "Principal":{"AWS":"arn:aws:iam::153765495495:user/andrewzick"},
      "Action": [
        "ecr:*"
      ]
    }
  ]
}
EOF
}

resource "aws_ecr_lifecycle_policy" "personal-website-ecr-lifecycle-policy" {
  repository = aws_ecr_repository.personal-website-ecr.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Expire untagged images older than 60 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 60
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "personal-website-logs" {
  name              = "personal-website-logs"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "personal-website-cluster" {
  name = "personal-website-cluster"
}

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

resource "aws_ecs_task_definition" "personal-website-task-definition" {
  family                = "personal-website-task"
  task_role_arn         = aws_iam_role.personal-website-task-role.arn
  execution_role_arn    = aws_iam_role.personal-website-task-role.arn
  container_definitions = <<EOF
[
  {
    "name": "personal-website",
    "image": "153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:v1",
    "cpu": 128,
    "memoryReservation": 128,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      },
      {
        "containerPort": 443,
        "hostPort": 443
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "personal-website-caddy-data",
        "containerPath": "/data"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "us-east-1",
        "awslogs-group": "personal-website-logs",
        "awslogs-stream-prefix": "complete-ecs"
      }
    }
  }
]
EOF

  volume {
    name = "personal-website-caddy-data"

    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
    }
  }
}

resource "aws_iam_role" "container-instance-ec2-role" {
  name               = "container-instance-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "container-instance-ec2-policy" {
  name  = "container-instance-ec2-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeTags",
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:UpdateContainerInstancesState",
        "ecs:Submit*",
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

resource "aws_iam_role_policy_attachment" "container-instance-ec2-policy-attachment" {
  role       = aws_iam_role.container-instance-ec2-role.name
  policy_arn = aws_iam_policy.container-instance-ec2-policy.arn
}

terraform {
  backend "s3" {
    bucket = "personal-website-tf-state-prod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket     = aws_s3_bucket.tf-state-s3.id
    key        = "network/terraform.tfstate"
    region     = var.region
    encrypt    = true
    kms_key_id = aws_kms_key.s3-enc-key.arn
  }
}