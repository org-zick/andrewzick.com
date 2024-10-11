provider "aws" {
  profile = "default"
  region  = var.region
}

provider "cloudflare" {}

resource "aws_kms_key" "s3-enc-key" {
  description             = "KMS key for encrypting S3 files in ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "tf-state-s3" {
  bucket = "personal-website-tf-state-${var.environment}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf-state-versioning" {
  bucket = aws_s3_bucket.tf-state-s3.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf-state-sse" {
  bucket = aws_s3_bucket.tf-state-s3.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3-enc-key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "tf-state-controls" {
  bucket = aws_s3_bucket.tf-state-s3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "tf-state-acl" {
  depends_on = [aws_s3_bucket_ownership_controls.tf-state-controls]

  bucket = aws_s3_bucket.tf-state-s3.id
  acl    = "private"
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

# website
resource "aws_s3_bucket" "static-website" {
  bucket = var.site_domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "static-website-versioning" {
  bucket = aws_s3_bucket.static-website.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.static-website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.static-website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.static-website.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "site" {
  bucket = aws_s3_bucket.static-website.id

  acl = "public-read"
  depends_on = [
    aws_s3_bucket_ownership_controls.site,
    aws_s3_bucket_public_access_block.site
  ]
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.static-website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.static-website.arn,
          "${aws_s3_bucket.static-website.arn}/*",
        ]
      },
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.site
  ]
}

data "cloudflare_zones" "domain" {
  filter {
    name = var.site_domain
  }
}

resource "cloudflare_record" "site_cname" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = var.site_domain
  value   = aws_s3_bucket_website_configuration.site.website_endpoint
  type    = "CNAME"

  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = "www"
  value   = var.site_domain
  type    = "CNAME"

  ttl     = 1
  proxied = true
}

resource "cloudflare_page_rule" "https" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  target  = "*.${var.site_domain}/*"
  actions {
    always_use_https = true
  }
}

resource "cloudflare_page_rule" "redirect_to_terraform" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  target  = "${var.site_domain}/learn"
  actions {
    forwarding_url {
      status_code = 302
      url         = "https://developer.hashicorp.com/terraform"
    }
  }
}
