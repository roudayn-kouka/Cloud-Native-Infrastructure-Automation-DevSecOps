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

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "engine_version" {
  description = "MySQL 8.4 is the current LTS line (8.0 is past standard support on RDS)."
  type        = string
  default     = "8.4"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ (recommended for production)."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "Set to false for anything you care about."
  type        = bool
  default     = true
}

variable "secret_recovery_window_days" {
  description = "0 deletes the secret immediately on destroy (dev); use 7-30 in production."
  type        = number
  default     = 0
}
