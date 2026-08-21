variable "name" {
  description = "Name prefix for security resources"
  type        = string
  default     = "devops-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the bastion"
  type        = list(string)
  
}
