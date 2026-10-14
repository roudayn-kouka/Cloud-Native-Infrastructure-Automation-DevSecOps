variable "project_name" {
  description = "Short project name used as a prefix for every resource."
  type        = string
  default     = "expense"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider's default_tags."
  type        = map(string)
  default = {
    Project     = "expense"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "roudayna-kouka"
  }
}

variable "zone_name" {
  description = "Public Route 53 hosted zone you own, e.g. example.com (no default on purpose)."
  type        = string
}

variable "deletion_protection" {
  type    = bool
  default = false
}
