output "bastion_instance_id" {
  description = "Bastion EC2 instance ID"
  value       = module.ec2.bastion_instance_id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = module.ec2.bastion_public_ip
}

output "bastion_private_ip" {
  description = "Bastion private IP"
  value       = module.ec2.bastion_private_ip
}

output "app_instance_id" {
  description = "Application EC2 instance ID"
  value       = module.ec2.app_instance_id
}

output "app_private_ip" {
  description = "Application private IP"
  value       = module.ec2.app_private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
