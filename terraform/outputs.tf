output "environment" {
  value = var.environment
}

output "region" {
  value = var.aws_region
}

output "availability_zone" {
  value = local.az
}

output "store_url" {
  description = "Endereço de acesso à loja."
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_eip.app.public_ip}"
}

output "app_public_ip" {
  description = "IP elástico da VM da aplicação (entrada pública e bastion SSH)."
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "db_private_ip" {
  description = "IP privado do MongoDB, usado pela API."
  value       = aws_instance.db.private_ip
}

output "db_public_ip" {
  description = "IP público da VM do banco (somente saída). Usado no teste que prova que a 27017 não aceita conexões externas."
  value       = aws_instance.db.public_ip
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "db_instance_id" {
  value = aws_instance.db.id
}

output "app_instance_type" {
  value = aws_instance.app.instance_type
}

output "db_instance_type" {
  value = aws_instance.db.instance_type
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "db_data_volume_id" {
  description = "Volume EBS com os dados do MongoDB."
  value       = aws_ebs_volume.mongo_data.id
}

output "ami_id" {
  value = aws_instance.app.ami
}

output "backup_bucket" {
  value = var.backup_bucket
}
