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

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to the bastion (e.g. [\"203.0.113.10/32\"]). Leave empty to disable SSH and use SSM Session Manager only."
  type        = list(string)
  default     = []
}
