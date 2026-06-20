# ===========================================================================
# Provisionamento da infraestrutura na AWS (Aula 2 - "Lab")
# Constrói: VPC -> Subnet -> Internet Gateway -> Route Table -> Association
#           -> Security Group -> Key Pair -> Instância EC2
# E gera automaticamente o inventário do Ansible (inventory/hosts.ini).
# ===========================================================================

# --- Busca a AMI mais recente do Ubuntu 22.04 LTS (evita AMI fixa quebrada) ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- VPC (Aula 2 - slide 29) ---
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr # Endereço IP da VPC
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.instance_name}-vpc" # Nome da VPC
  }
}

# --- Sub-rede pública (Aula 2 - slide 30) ---
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id # ID da VPC onde a sub-rede será criada
  cidr_block              = var.subnet_cidr     # Endereço IP da sub-rede
  map_public_ip_on_launch = true                # Atribui IP público às instâncias

  tags = {
    Name = "${var.instance_name}-public-subnet" # Nome da sub-rede
  }
}

# --- Internet Gateway (Aula 2 - slide 31) ---
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id # VPC à qual a IGW será associada

  tags = {
    Name = "${var.instance_name}-igw" # Nome da IGW
  }
}

# --- Tabela de rotas + associação (Aula 2 - slides 32 e 33) ---
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Rota padrão para a Internet
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.instance_name}-public-rt" # Nome da tabela de roteamento
  }
}

resource "aws_route_table_association" "public_route_association" {
  subnet_id      = aws_subnet.public_subnet.id           # ID da sub-rede pública
  route_table_id = aws_route_table.public_route_table.id # ID da tabela de roteamento
}

# --- Security Group (firewall na borda — complementa o UFW do hardening) ---
resource "aws_security_group" "servidor_sg" {
  name        = "${var.instance_name}-sg"
  description = "Libera SSH, HTTP, HTTPS e Node Exporter"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# --- Par de chaves SSH (envia sua chave pública para a AWS) ---
resource "aws_key_pair" "deployer" {
  key_name   = "${var.instance_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# --- Instância EC2 (Aula 2 - slides 19 e 28 "Criando Instâncias") ---
resource "aws_instance" "servidor" {
  ami                    = data.aws_ami.ubuntu.id              # ID da imagem (Ubuntu 22.04)
  instance_type          = var.instance_type                   # Tipo de instância
  key_name               = aws_key_pair.deployer.key_name      # Chave SSH de acesso
  subnet_id              = aws_subnet.public_subnet.id         # Sub-rede pública
  vpc_security_group_ids = [aws_security_group.servidor_sg.id] # Firewall

  tags = {
    Name = var.instance_name # Tag para identificar a instância
  }
}

# ===========================================================================
# Geração automática do inventário do Ansible a partir do estado do Terraform
# (handoff Terraform -> Ansible). Usa o template em templates/inventory.tftpl.
# ===========================================================================
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../inventory/hosts.ini"
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    public_ip        = aws_instance.servidor.public_ip
    ssh_user         = "ubuntu"
    private_key_path = var.ssh_private_key_path
  })
}
