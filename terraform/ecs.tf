resource "aws_cloudwatch_log_group" "personal-website-logs" {
  name              = "personal-website-logs"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "personal-website-cluster" {
  name = local.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.personal-website-cap-provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.personal-website-cap-provider.name
  }
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
    "image": "153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:4",
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

# From here: https://gist.githubusercontent.com/paweldudzinski/c536455fa8f1d74ffc9bce9f1396a6a9/raw/1a8c86e4cd4fd9e5e8008c04d23d21da0a29697e/iam.tf
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

resource "aws_iam_instance_profile" "ecs-agent-profile" {
  name = "ecs-agent-profile"
  # path = "/"
  role = aws_iam_role.ecs-agent-role.name
}

resource "aws_launch_configuration" "container-instance-launch-configuration" {
  name_prefix = "ecs-personal-website-"

  iam_instance_profile = aws_iam_instance_profile.ecs-agent-profile.name

  instance_type               = "t3a.nano"
  image_id                    = data.aws_ami.amazon-linux-2.id
  key_name                    = aws_key_pair.aws-ec2-ssh-key-pair.id
  associate_public_ip_address = true  # careful with this
  security_groups             = [aws_security_group.pw-sg-allow-ssh.id, aws_security_group.pw-sg-allow-web-traffic.id]

  root_block_device {
    volume_type           = "standard"
    volume_size           = 30  # Autoscaling error said 30GB+ needed to start EC2
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<EOF
#!/bin/bash
# The cluster this agent should check into.
echo 'ECS_CLUSTER=${local.cluster_name}' >> /etc/ecs/ecs.config
# Enable ECS task role.
ECS_ENABLE_TASK_IAM_ROLE=true
# Disable privileged containers.
echo 'ECS_DISABLE_PRIVILEGED=true' >> /etc/ecs/ecs.config
EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "personal-website-asg" {
  name                 = "personal-website-asg"
  launch_configuration = aws_launch_configuration.container-instance-launch-configuration.name
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.pw-public-subnet.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_capacity_provider" "personal-website-cap-provider" {
  name = "personal-website-cap-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.personal-website-asg.arn

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 75  # this is actually the CPU usage
    }
  }
}

resource "aws_ecs_service" "personal-website-service" {
  name            = "personal-website-service"
  cluster         = aws_ecs_cluster.personal-website-cluster.id
  task_definition = aws_ecs_task_definition.personal-website-task-definition.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.pw-nlb-target-group-port-80.arn
    container_name   = "personal-website"
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pw-nlb-target-group-port-443.arn
    container_name   = "personal-website"
    container_port   = 443
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.personal-website-cap-provider.arn
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }
}
