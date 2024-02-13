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

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
