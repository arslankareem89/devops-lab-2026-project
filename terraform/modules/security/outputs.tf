output "bastion_security_group_id" {
  description = "Security group ID for the bastion"
  value       = aws_security_group.bastion.id
}

output "app_security_group_id" {
  description = "Security group ID for the application server"
  value       = aws_security_group.app.id
}
