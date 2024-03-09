#!/bin/bash

# The cluster this agent should check into
echo "ECS_CLUSTER=personal-website-cluster-4" >> /etc/ecs/ecs.config

# Enable ECS task role
ECS_ENABLE_TASK_IAM_ROLE=true

# Disable privileged containers
echo "ECS_DISABLE_PRIVILEGED=true" >> /etc/ecs/ecs.config
