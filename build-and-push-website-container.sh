#!/usr/bin/env bash

# Log into ECR
aws ecr get-login-password | docker login --username AWS --password-stdin 153765495495.dkr.ecr.us-east-1.amazonaws.com

# Get the most recent (aka highest number) imageId
IMAGE_ID=$(aws ecr describe-images --repository-name personal-website --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n' | tail -1)

# Increment the imageId by 1
let "IMAGE_ID=((IMAGE_ID + 1))"

# Build the container with target PROD, passing in the correct tag number
docker build -f Dockerfile --target PROD -t 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:$IMAGE_ID

# Push the container
docker push 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:$IMAGE_ID

# Print out the new imageId for updating the terraform ECS task
echo $IMAGE_ID
echo "Update the terraform ECS task with this new imageId"