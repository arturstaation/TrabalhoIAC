# ===========================================================================
# Saídas (Aula 2 - slide 24 "Outputs"/"Functions")
# ===========================================================================

output "instance_id" {
  description = "ID da instância EC2 criada."
  value       = aws_instance.servidor.id
}

output "public_ip" {
  description = "IP público da instância (use para acessar via SSH/Ansible)."
  value       = aws_instance.servidor.public_ip
}

output "ssh_command" {
  description = "Comando pronto para conectar via SSH."
  value       = format("ssh -i %s ubuntu@%s", var.ssh_private_key_path, aws_instance.servidor.public_ip)
}

output "ansible_ping" {
  description = "Comando para testar a conexão com o Ansible (Aula 3)."
  value       = "ansible all -m ping"
}
