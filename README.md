# Trabalho Final — Infrastructure as Code (IaC)

**Disciplina:** Infrastructure as Code (IaC) — Faculdade de Computação e Informática, Universidade Presbiteriana Mackenzie
**Professor:** Felipe Gualdi
**Ferramentas:** Terraform + Ansible

---

## 1. Cenário

Você é responsável por gerenciar a infraestrutura de uma pequena empresa que possui
servidores Linux, serviços de rede e segurança. A empresa deseja automatizar várias
tarefas de gerenciamento de infraestrutura usando **Terraform** e **Ansible**.

Este repositório implementa, de ponta a ponta, a automação dessa infraestrutura
seguindo os conceitos vistos em aula: IaC declarativa, versionamento em Git,
modularização em **roles**, reprodutibilidade entre ambientes e gestão de segredos
com **Ansible Vault**.

## 2. O que está implementado

| # | Tarefa do enunciado | Onde está | Status |
|---|---------------------|-----------|--------|
| 1 | **Configuração Inicial** (pacotes, usuários/grupos, segurança básica) | `roles/configuracao_inicial` | ✅ Obrigatória |
| 2 | **Gerenciamento de Pacotes** (instalar / atualizar / remover) | `roles/gerenciamento_pacotes` | ✅ Obrigatória |
| 3 | **Hardening de Segurança** (firewall, serviços, política de senha) | `roles/hardening` | ✅ Obrigatória |
| 4 | **Integração Contínua (CI/CD)** | `.gitlab-ci.yml` + `.github/workflows/ci.yml` | ✅ Obrigatória |
| 5 | **Monitoramento e Logging** (Node Exporter + rsyslog/logrotate) | `roles/monitoramento` | ⭐ Desafio |
| 6 | **Backup e Recuperação** | `roles/backup` | ⭐ Desafio |

E o **provisionamento da máquina** (Terraform) está em `terraform/` — cria uma EC2
Ubuntu na AWS e **gera automaticamente o inventário do Ansible**.

## 3. Estrutura de diretórios

Seguindo as boas práticas de arquitetura e estrutura de diretórios apresentadas nas
Aulas 1 e 2 (raiz com config principal, `modules/`, `environments/`) e a estrutura
de roles da Aula 4:

```
trabalho-iac/
├── README.md
├── ansible.cfg                  # Configuração do Ansible
├── requirements.yml             # Collections do Ansible Galaxy
├── .gitlab-ci.yml               # Pipeline CI/CD (GitLab)
├── .github/workflows/ci.yml     # Pipeline CI/CD (GitHub Actions)
│
├── terraform/                   # Provisionamento AWS (Aula 2)
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── templates/inventory.tftpl
│
├── inventory/                   # Inventário estático (Aula 3 e 6)
│   ├── hosts.ini
│   ├── group_vars/
│   │   └── all/
│   │       ├── vars.yml         # variáveis públicas (versionável)
│   │       └── vault.yml        # variáveis sensíveis (CRIPTOGRAFAR com Vault)
│   └── host_vars/
│
├── playbooks/                   # Playbooks (Aula 4)
│   ├── site.yml                 # orquestra tudo
│   ├── 01-configuracao-inicial.yml
│   ├── 02-gerenciamento-pacotes.yml
│   ├── 03-hardening.yml
│   ├── 04-monitoramento.yml
│   └── 05-backup.yml
│
├── roles/                       # Roles reutilizáveis (Aula 4)
│   ├── configuracao_inicial/
│   ├── gerenciamento_pacotes/
│   ├── hardening/
│   ├── monitoramento/
│   └── backup/
│
├── docker/                      # Alvo de teste local gratuito
│   ├── docker-compose.yml
│   └── Dockerfile
│
└── docs/
    └── RELATORIO.md             # Relatório do trabalho
```

## 4. Pré-requisitos

No seu computador (nó de controle / control node):

```bash
# Ansible (Aula 3)
sudo apt update
sudo apt install ansible

# Terraform (Aula 2) — apenas se for usar a AWS
sudo apt-get update
sudo apt-get install terraform

# Collections usadas pelas roles
ansible-galaxy collection install -r requirements.yml
```

> No Windows, rode tudo dentro do **WSL2 (Ubuntu)** — é a forma mais simples de ter
> Ansible/Terraform funcionando.

---

## 5. Como executar

Há **dois caminhos**. Escolha o que preferir.

### Caminho A — AWS EC2 (Terraform provisiona a máquina)

Fiel à Aula 2 (provider `aws`). Requer uma conta AWS e credenciais configuradas
(`aws configure` ou variáveis de ambiente `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste a chave SSH e a região
terraform init
terraform plan
terraform apply
```

O `apply` cria a EC2 **e escreve o arquivo `inventory/hosts.ini`** já com o IP público.
Depois, rode os playbooks:

```bash
cd ..
ansible all -m ping                                  # testa conectividade (Aula 3)
ansible-playbook playbooks/site.yml --ask-vault-pass # aplica tudo
```

Para destruir e parar de pagar:

```bash
cd terraform && terraform destroy
```

### Caminho B — Docker local (gratuito, ótimo para testar)

Sobe um container Ubuntu **com systemd** (necessário para UFW, fail2ban e os serviços),
sem custo nenhum. Ideal para validar os playbooks e tirar prints.

```bash
cd docker
docker compose up -d         # sobe o container "servidor-linux"
cd ..
ansible all -m ping          # já usa o inventário docker
ansible-playbook playbooks/site.yml --ask-vault-pass
```

> O inventário `inventory/hosts.ini` já vem com um host local apontando para o container
> via `ansible_connection=docker`. Veja o arquivo `docker/docker-compose.yml`.

---

## 6. Ansible Vault (gestão de segredos — Aula 5)

As senhas (usuário admin, etc.) ficam em `inventory/group_vars/all/vault.yml`.
**Esse arquivo deve ser criptografado** antes de subir para o GitHub:

```bash
# criptografar o arquivo de segredos
ansible-vault encrypt inventory/group_vars/all/vault.yml

# editar depois (sem deixar em texto puro no disco)
ansible-vault edit inventory/group_vars/all/vault.yml

# visualizar
ansible-vault view inventory/group_vars/all/vault.yml
```

Ao rodar os playbooks, informe a senha do cofre com `--ask-vault-pass`
(ou `--vault-password-file`).

## 7. Mapeamento com o conteúdo das aulas

- **Aula 1** — Conceitos de IaC, boas práticas de arquitetura, estrutura de diretórios, versionamento em Git.
- **Aula 2** — Terraform: `provider`, `resource`, `variable`, `output`, estado, `terraform apply`.
- **Aula 3** — Ansible agentless via SSH, inventário INI, `ansible all -m ping`, módulos ad-hoc.
- **Aula 4** — Playbooks (`hosts`, `become`, `tasks`), roles, handlers, templates Jinja2, `loop`.
- **Aula 5** — Segurança: Ansible Vault, hardening (firewall, serviços, política de senha).
- **Aula 6** — Inventário estático/dinâmico, variáveis (`vars`, `vars_files`, group_vars), CI/CD.
- **Aula 7** — Ansible Galaxy (`ansible-galaxy install`), AWX para gerenciar playbooks.

## 8. Autor

Artur Valladares — Trabalho Final da disciplina de IaC.
