variable "region" {
  type        = string
  description = "AWS Region"
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "The environment being deployed to."
  default = "dev"
}

variable "site_domain" {
  type        = string
  description = "The domain name to use for the static site"
}
