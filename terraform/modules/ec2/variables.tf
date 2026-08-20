variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for bastion"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for application server"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID for bastion"
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID for application server"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to install on the bastion"
  type        = string
}

variable "ci_instance_type" {
  description = "CI/CD EC2 instance type (Jenkins + SonarQube + PostgreSQL)"
  type        = string
  default     = "c7i-flex.large"
}

