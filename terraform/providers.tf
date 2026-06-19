# ===========================================================================
# Configuração do provedor (Aula 2 - slide 18 "Providers")
# ===========================================================================
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Provider auxiliar para gerar a chave/arquivos locais
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Provedor para a AWS, especificando a região (Aula 2 - slide 18)
provider "aws" {
  region = var.aws_region
}
