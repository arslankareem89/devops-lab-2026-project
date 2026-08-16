variable "name" {
  description = "Name prefix for IAM resources"
  type        = string
  default     = "devops-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
