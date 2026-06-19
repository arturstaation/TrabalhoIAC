# ===========================================================================
# Declaração de variáveis (Aula 2 - slide 22 "Variables")
# Os valores reais ficam em terraform.tfvars (a partir do .example).
# ===========================================================================

variable "aws_region" {
  type        = string
  description = "Região da AWS onde a infraestrutura será provisionada."
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância EC2 (t2.micro está no nível gratuito)."
  default     = "t2.micro"
}

variable "instance_name" {
  type        = string
  description = "Nome (tag Name) da instância e do servidor."
  default     = "servidor-linux-iac"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Caminho para a sua chave pública SSH (ex.: ~/.ssh/id_rsa.pub)."
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Caminho para a sua chave privada SSH (usada pelo Ansible)."
  default     = "~/.ssh/id_rsa"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Bloco CIDR autorizado a acessar a porta SSH. Restrinja ao seu IP!"
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloco CIDR da VPC (Aula 2 - slide 29)."
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Bloco CIDR da sub-rede pública (Aula 2 - slide 30)."
  default     = "10.0.1.0/24"
}
