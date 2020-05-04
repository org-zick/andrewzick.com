provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_kms_key" "s3-enc-key" {
  description             = "KMS key for encrypting S3 files in ${var.env}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "tf-state-s3" {
  bucket = "terraform-state-${var.env}"
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
        kms_master_key_id = "${aws_kms_key.s3-enc-key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "tf-state-policy" {
  bucket = "${aws_s3_bucket.tf-state-s3.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "${aws_s3_bucket.tf-state-s3.arn}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "${aws_s3_bucket.tf-state-s3.arn}/network/terraform.tfstate"
    }
  ]
}
EOF
}

data "terraform_remote_state" "network" {
  backend  = "s3"
  encrypt  = true
  config   = {
    bucket = "${aws_s3_bucket.tf-state-s3.id}"
    key    = "network/terraform.tfstate"
    region = var.region
  }
}