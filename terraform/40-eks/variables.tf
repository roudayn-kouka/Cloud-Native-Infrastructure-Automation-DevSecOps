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

variable "cluster_version" {
  description = "Kubernetes version. Check the EKS support calendar: versions past standard support are billed at the extended-support rate."
  type        = string
  default     = "1.35"
}

variable "cluster_service_ipv4_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "cluster_endpoint_public_access" {
  description = "Keep true only for labs; use private access + bastion/VPN in production."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
}

variable "node_capacity_type" {
  description = "SPOT (cheap, interruptible) or ON_DEMAND."
  type        = string
  default     = "SPOT"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 10
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "ssh_public_key_path" {
  description = "Optional path to a public key for SSH access to nodes. Empty = no SSH key (use SSM)."
  type        = string
  default     = ""
}
