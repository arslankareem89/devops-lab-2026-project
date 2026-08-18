output "bastion_instance_id" {
  description = "Bastion EC2 instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Bastion private IP"
  value       = aws_instance.bastion.private_ip
}

output "app_instance_id" {
  description = "Application EC2 instance ID"
  value       = aws_instance.app.id
}

output "app_private_ip" {
  description = "Application private IP"
  value       = aws_instance.app.private_ip
}
