
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
  default = true
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

variable "node_group_name" {
  type        = string
  description = "Name of the default managed node group"
  default     = "mng-eks-demo"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the node group"
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  type        = number
  description = "Desired nodes"
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Min nodes"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Max nodes"
  default     = 3
}

variable "node_disk_size" {
  type        = number
  description = "Node volume size (GiB)"
  default     = 20
}

variable "node_ami_type" {
  type        = string
  description = "AMI type for node group (e.g., AL2_x86_64, BOTTLEROCKET_x86_64, AL2_ARM_64)"
  default     = "AL2_x86_64"
}

