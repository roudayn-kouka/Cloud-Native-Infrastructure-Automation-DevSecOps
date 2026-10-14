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

variable "force_delete" {
  description = "Allow Terraform to delete repositories that still contain images (labs only)."
  type        = bool
  default     = false
}

variable "images_to_keep" {
  type    = number
  default = 20
}
