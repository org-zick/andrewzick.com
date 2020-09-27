# resource "aws_cloudwatch_log_group" "personal-website-logs" {
#   name              = "personal-website-logs"
#   retention_in_days = 7
# }

# resource "aws_ecs_cluster" "personal-website-cluster" {
#   name = local.cluster_name
#   capacity_providers = [aws_ecs_capacity_provider.personal-website-cp.name]

#   default_capacity_provider_strategy {
#     capacity_provider = aws_ecs_capacity_provider.personal-website-cp.name
#   }
# }

# resource "aws_iam_role" "personal-website-task-role" {
#   name = "personal-website-task-role"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "",
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "ecs-tasks.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_policy" "personal-website-task-policy" {
#   name  = "personal-website-task-policy"

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "ecr:GetAuthorizationToken",
#         "ecr:BatchCheckLayerAvailability",
#         "ecr:GetDownloadUrlForLayer",
#         "ecr:BatchGetImage",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ],
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "personal-website-task-policy-attachment" {
#   role       = aws_iam_role.personal-website-task-role.name
#   policy_arn = aws_iam_policy.personal-website-task-policy.arn
# }

# resource "aws_ecs_task_definition" "personal-website-task-definition" {
#   family                = "personal-website-task"
#   task_role_arn         = aws_iam_role.personal-website-task-role.arn
#   execution_role_arn    = aws_iam_role.personal-website-task-role.arn
#   container_definitions = <<EOF
# [
#   {
#     "name": "personal-website",
#     "image": "153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:v1",
#     "cpu": 128,
#     "memoryReservation": 128,
#     "essential": true,
#     "portMappings": [
#       {
#         "containerPort": 80,
#         "hostPort": 80
#       },
#       {
#         "containerPort": 443,
#         "hostPort": 443
#       }
#     ],
#     "mountPoints": [
#       {
#         "sourceVolume": "personal-website-caddy-data",
#         "containerPath": "/data"
#       }
#     ],
#     "logConfiguration": {
#       "logDriver": "awslogs",
#       "options": {
#         "awslogs-region": "us-east-1",
#         "awslogs-group": "personal-website-logs",
#         "awslogs-stream-prefix": "complete-ecs"
#       }
#     }
#   }
# ]
# EOF

#   volume {
#     name = "personal-website-caddy-data"

#     docker_volume_configuration {
#       scope         = "shared"
#       autoprovision = true
#     }
#   }
# }

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

resource "aws_iam_instance_profile" "container-instance-ec2-profile" {
  name = "container-instance-ec2-profile"
  path = "/"
  role = aws_iam_role.container-instance-ec2-role.name
}

resource "aws_launch_configuration" "container-instance-launch-configuration" {
  name_prefix = "ecs-personal-website-"

  iam_instance_profile = aws_iam_instance_profile.container-instance-ec2-profile.name

  instance_type               = "t3a.nano"
  image_id                    = data.aws_ami.ubuntu_20-04_LTS_ami.id
  key_name                    = aws_key_pair.aws-ec2-ssh-key-pair.id
  associate_public_ip_address = true  # careful with this
  security_groups             = [aws_security_group.pw-sg-allow-ssh.id, aws_security_group.pw-sg-allow-web-traffic.id]

  root_block_device {
    volume_type           = "standard"
    volume_size           = 10
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

# resource "aws_ecs_capacity_provider" "personal-website-cp" {
#   name = "personal-website-cp"

#   auto_scaling_group_provider {
#     auto_scaling_group_arn = aws_autoscaling_group.personal-website-asg.arn

#     managed_scaling {
#       maximum_scaling_step_size = 10
#       minimum_scaling_step_size = 1
#       status                    = "ENABLED"
#       target_capacity           = 75
#     }
#   }
# }

# resource "aws_ecs_service" "personal-website-service" {
#   name            = "personal-website-service"
#   cluster         = aws_ecs_cluster.personal-website-cluster.id
#   task_definition = aws_ecs_task_definition.personal-website-task-definition.arn
#   desired_count   = 1

#   capacity_provider_strategy {
#     capacity_provider = aws_ecs_capacity_provider.personal-website-cp.arn
#     weight            = 100
#   }

#   ordered_placement_strategy {
#     type  = "binpack"
#     field = "cpu"
#   }

#   # Optional: Allow external changes without Terraform plan difference
#   lifecycle {
#     ignore_changes = [desired_count]
#   }
# }
