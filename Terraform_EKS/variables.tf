
# variables.tf

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Name used for tagging and cluster naming"
  default     = "demo-eks"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}


variable "tags" {
  type = map(string)
  default = {
    Project     = "demo-eks"
    ManagedBy   = "terraform"
    CostCenter  = "eks-labs"
    AutoDelete  = "true" # optional convention for cleanup tooling
  }
}

