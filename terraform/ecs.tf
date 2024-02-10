resource "aws_cloudwatch_log_group" "personal-website-logs" {
  name              = "personal-website-logs"
  retention_in_days = 400
}

resource "aws_ecs_cluster" "personal-website-cluster" {
  name = local.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.personal-website-cap-provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.personal-website-cap-provider.name
  }
}

resource "aws_ecs_capacity_provider" "personal-website-cap-provider" {
  name = "personal-website-cap-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.personal-website-asg.arn

    managed_scaling {
      maximum_scaling_step_size = 4
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      # This is actually the CPU usage, don't need it for only 1 instance
      # target_capacity           = 75
    }
  }
}

resource "aws_ecs_service" "personal-website-service" {
  name            = "personal-website-service"
  cluster         = aws_ecs_cluster.personal-website-cluster.id
  task_definition = aws_ecs_task_definition.personal-website-task-definition.arn
  desired_count   = 1

  force_new_deployment = true

  capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.personal-website-cap-provider.arn
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pw-nlb-target-group-port-80.arn
    container_name   = "personal-website" # as it appears in the container definition
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pw-nlb-target-group-port-443.arn
    container_name   = "personal-website" # as it appears in the container definition
    container_port   = 443
  }

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  # Optional: Allow external changes without Terraform plan difference
  # You can act out of annoyance and add "capacity_provider_strategy" here
  lifecycle {
    ignore_changes = [desired_count, capacity_provider_strategy]
  }
}

resource "aws_ecs_task_definition" "personal-website-task-definition" {
  family                = "personal-website-task"
  task_role_arn         = aws_iam_role.personal-website-task-role.arn
  execution_role_arn    = aws_iam_role.personal-website-task-role.arn
  container_definitions = file("${path.module}/personal-website-task-definition.json")

  volume {
    name = "personal-website-caddy-data"

    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
    }
  }
}

resource "aws_launch_template" "container-ec2-template" {
  name_prefix = "ecs-personal-website-"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs-agent-profile.name
  }

  instance_type               = "t3a.micro"
  image_id                    = data.aws_ami.amazon-linux-2023.id
  key_name                    = aws_key_pair.aws-ec2-ssh-key-pair.id

  user_data = filebase64("${path.module}/ecs-container-prep.sh")

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_type           = "standard"
      volume_size           = 30  # Autoscaling error said 30GB+ needed to start EC2
      delete_on_termination = true
      encrypted             = true
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.pw-sg-allow-ssh.id, aws_security_group.pw-sg-allow-web-traffic.id]
    subnet_id                   = aws_subnet.pw-public-subnet.id
  }

  tag_specifications {
   resource_type = "instance"
   tags = {
     Name = "ecs-instance"
   }
 }
}

resource "aws_autoscaling_group" "personal-website-asg" {
  name                      = "personal-website-asg"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier  = [aws_subnet.pw-public-subnet.id]

  launch_template {
    id      = aws_launch_template.container-ec2-template.id
    version = aws_launch_template.container-ec2-template.latest_version
  }

  # instance_refresh {
  #   strategy = "Rolling"
  #   preferences {
  #     min_healthy_percentage = 50
  #   }
  # }

  lifecycle {
    create_before_destroy = true
  }
}
