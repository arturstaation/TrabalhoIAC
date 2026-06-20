# Trabalho Final — Infrastructure as Code (IaC)

![CI](https://github.com/arturstaation/TrabalhoIAC/actions/workflows/ci.yml/badge.svg)

**Disciplina:** Infrastructure as Code (IaC) — Faculdade de Computação e Informática, Universidade Presbiteriana Mackenzie
**Professor:** Felipe Gualdi
**Aluno:** Artur Valladares
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

As **4 tarefas obrigatórias** e os **2 desafios** do enunciado:

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

> 📚 **Documentação complementar** (na pasta `docs/`):
> - [`docs/GUIA_APRESENTACAO.md`](docs/GUIA_APRESENTACAO.md) — roteiro de apresentação, como testar e explicação de cada parte
> - [`docs/RELATORIO.md`](docs/RELATORIO.md) — relatório do trabalho
> - [`docs/EVIDENCIAS.md`](docs/EVIDENCIAS.md) — saídas reais comprovando que funciona

## 3. Como funciona (visão geral)

```
                    ┌──────────────────┐
                    │   Git / GitHub   │  ← versionamento (Aula 1)
                    └────────┬─────────┘
                             │ git push → dispara o CI/CD (valida tudo)
                             ▼
        ┌───────────────────────────────────────────┐
        │  Nó de Controle (seu PC / WSL / container)  │
        │  - Terraform → provisiona a máquina (AWS)   │
        │  - Ansible   → configura via SSH (agentless)│
        └───────────────┬─────────────────┬──────────┘
                        │                 │
              terraform apply       ansible-playbook site.yml
                        ▼                 ▼
        ┌───────────────────────────────────────────┐
        │   Servidor Linux (EC2 na AWS OU container)  │
        │   5 roles aplicadas em sequência:           │
        │   configuracao_inicial → pacotes →          │
        │   hardening → monitoramento → backup        │
        └───────────────────────────────────────────┘
```

**A ideia central:** o **Terraform** cria o servidor e, ao terminar, escreve o
inventário do Ansible (`inventory/hosts.ini`) com o IP da máquina. Em seguida o
**Ansible** se conecta nesse servidor por SSH (sem instalar agente nenhum) e aplica
as **roles**, que descrevem o estado desejado do servidor de forma **declarativa**.

## 4. Estrutura de diretórios

```
trabalho-iac/
├── README.md
├── testar-local.sh             # sobe e configura TUDO no Docker (1 comando)
├── ansible.cfg                 # Configuração do Ansible
├── requirements.yml            # Collections do Ansible Galaxy (Aula 7)
├── .yamllint / .ansible-lint   # Regras de lint usadas no CI
├── .gitlab-ci.yml              # Pipeline CI/CD (GitLab)
├── .github/workflows/ci.yml    # Pipeline CI/CD (GitHub Actions)
│
├── terraform/                  # Provisionamento AWS (Aula 2)
│   ├── providers.tf            # provider "aws"
│   ├── variables.tf            # variáveis de entrada
│   ├── main.tf                 # VPC, subnet, IGW, route table, SG, EC2
│   ├── outputs.tf              # IP público, comando SSH, etc.
│   ├── terraform.tfvars.example
│   └── templates/inventory.tftpl   # gera o inventário do Ansible
│
├── inventory/                  # Inventário estático (Aulas 3 e 6)
│   ├── hosts.ini               # lista de servidores (grupos aws / local)
│   ├── group_vars/all/
│   │   ├── vars.yml            # variáveis públicas (versionável)
│   │   └── vault.yml           # variáveis sensíveis (CRIPTOGRAFAR c/ Vault)
│   └── host_vars/
│
├── playbooks/                  # Playbooks (Aula 4)
│   ├── site.yml                # orquestra as 5 roles
│   ├── 01-configuracao-inicial.yml
│   ├── 02-gerenciamento-pacotes.yml
│   ├── 03-hardening.yml
│   ├── 04-monitoramento.yml
│   └── 05-backup.yml
│
├── roles/                      # Roles reutilizáveis (Aula 4)
│   ├── configuracao_inicial/   # T1 — usuários, pacotes base, segurança básica
│   ├── gerenciamento_pacotes/  # T2 — instala/atualiza/remove + página nginx
│   ├── hardening/              # T3 — UFW, SSH, senha, fail2ban
│   ├── monitoramento/          # Desafio — Node Exporter + rsyslog/logrotate
│   └── backup/                 # Desafio — backup tar.gz + cron + restore
│       (cada role tem: tasks/ defaults/ meta/ e, quando precisa, handlers/ templates/)
│
├── docker/                     # Alvo de teste local gratuito
│   ├── docker-compose.yml      # sobe o container "servidor-linux" (systemd)
│   └── Dockerfile              # Ubuntu 22.04 + systemd + python + ssh
│
└── docs/                       # Documentação
    ├── GUIA_APRESENTACAO.md
    ├── RELATORIO.md
    ├── EVIDENCIAS.md
    └── img/pagina-servidor.png
```

## 5. Explicação de cada componente (o quê e por quê)

### `terraform/` — provisiona a máquina (Aula 2)
Define a infraestrutura na AWS de forma declarativa: **VPC → sub-rede → internet
gateway → tabela de rotas → security group → instância EC2 (Ubuntu 22.04)**. Ao
final, o recurso `local_file` **gera o `inventory/hosts.ini`** do Ansible com o IP
público — conectando as duas ferramentas automaticamente. Comandos: `terraform init`
→ `plan` → `apply` (e `destroy` para remover).

### `inventory/` — quem é gerenciado (Aulas 3 e 6)
- `hosts.ini`: lista de servidores no formato INI, com os grupos `aws` (EC2) e `local` (container).
- `group_vars/all/vars.yml`: **todas as variáveis públicas** (listas de pacotes, portas do firewall, política de senha…). Mudar o comportamento sem tocar nas tasks.
- `group_vars/all/vault.yml`: **segredos** (senhas), criptografados com **Ansible Vault**.

### `playbooks/` — o que executar (Aula 4)
`site.yml` chama as 5 roles na ordem. Os playbooks `01..05` permitem rodar cada tarefa
isolada. Conceitos: `hosts` (onde roda), `become: true` (vira root/sudo), `roles:` (o que aplicar).

### `roles/configuracao_inicial` — Tarefa 1
Atualiza pacotes, define fuso horário, instala pacotes base com **`loop`**, cria o
**grupo `devops`** e o **usuário `deploy`** (módulos `group`/`user`), concede sudo,
autoriza a chave SSH e instala um banner de aviso. Garante o SSH ativo.

### `roles/gerenciamento_pacotes` — Tarefa 2
**Instala** (`state: present`), **atualiza** (`state: latest` + upgrade do sistema) e
**remove** (`state: absent`) pacotes — tudo por listas em `vars.yml`. Inicia o nginx e
publica uma **página de demonstração** (template Jinja2) como prova visual.

### `roles/hardening` — Tarefa 3 (segurança — Aula 5)
- **UFW**: firewall com política padrão *negar entrada*, liberando só 22/80/443/9100.
- **Serviços**: desativa avahi/cups/rpcbind (módulo `systemd`).
- **SSH**: desabilita login de root, exige chave, restringe usuários (`lineinfile` com `validate: sshd -t` para não se trancar para fora).
- **Senha**: validade e complexidade mínimas (`login.defs` + `pwquality`).
- **fail2ban**: bane IPs que erram a senha do SSH (template `jail.local.j2`).
- **Handlers + notify**: SSH/fail2ban só reiniciam quando algo realmente muda.

### `roles/monitoramento` — Desafio
**Monitoramento:** instala o **Prometheus Node Exporter** como serviço systemd
(métricas em `:9100/metrics`). **Logging:** `rsyslog` (encaminhamento opcional) +
`logrotate` (rotação). *O enunciado permite escolha livre de ferramentas; optei por uma
stack leve, 100% instalável via Ansible, em vez de Nagios/ELK.*

### `roles/backup` — Desafio
Script de **backup** (`.tar.gz` de `/etc`, `/home`, `/var/www`) agendado via **cron**
(02:30), com **retenção** de 7 dias, e um script de **restore** para recuperação.

### `.gitlab-ci.yml` / `.github/workflows/ci.yml` — Tarefa 4 (CI/CD)
Pipeline que **roda automaticamente a cada `git push`**, com estágios
**lint → validate → deploy**: `yamllint`, `ansible-lint`,
`ansible-playbook --syntax-check` e `terraform validate`. Ver seção 8.

## 6. Pré-requisitos

No nó de controle (seu PC):

```bash
# Ansible (Aula 3)
sudo apt update && sudo apt install ansible

# Terraform (Aula 2) — apenas se for usar a AWS
sudo apt-get update && sudo apt-get install terraform

# Collections usadas pelas roles
ansible-galaxy collection install -r requirements.yml
```

> No Windows, a forma mais simples de testar é o **Caminho B (Docker)** abaixo — não
> exige instalar Ansible no host.

## 7. Como executar

Há **dois caminhos**. Escolha o que preferir.

### Caminho A — AWS EC2 (Terraform provisiona a máquina)

Fiel à Aula 2 (provider `aws`). Requer conta AWS e credenciais
(`aws configure` ou `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste a chave SSH e a região
terraform init
terraform plan
terraform apply                                 # cria a EC2 e gera o hosts.ini
cd ..
ansible all -m ping                             # testa conectividade (Aula 3)
ansible-playbook playbooks/site.yml --ask-vault-pass
cd terraform && terraform destroy               # para parar de pagar
```

### Caminho B — Docker local (gratuito, recomendado para testar)

Sobe um container Ubuntu 22.04 **com systemd** (necessário para UFW, fail2ban e os
serviços) e aplica todos os playbooks. **Um comando:**

```bash
./testar-local.sh
```

O script: (1) confere o Docker, (2) sobe o container `servidor-linux`, (3) instala o
Ansible nele, (4) testa o `ping` e (5) aplica o `site.yml`. Ao final mostra as URLs.

> Detalhe técnico: como o Windows não tem Ansible nativo, no teste local o Ansible roda
> **de dentro do container** (conexão local). As roles e o resultado são idênticos ao
> da AWS — muda apenas de onde o comando é disparado.

Resultado esperado: `PLAY RECAP ... failed=0`.

#### O que fica acessível no navegador (do seu Windows)

| URL | Serviço |
|-----|---------|
| http://localhost:8080 | Página do servidor (nginx) — prova visual do provisionamento |
| http://localhost:9100/metrics | Métricas do servidor (Prometheus Node Exporter) |

#### Derrubar / recriar do zero (demo de reprodutibilidade)

```bash
docker compose -f docker/docker-compose.yml down -v   # destrói tudo
./testar-local.sh                                      # recria do zero (~3-4 min)
```

## 8. Integração Contínua (CI/CD) — Tarefa 4

O pipeline está em `.github/workflows/ci.yml` (GitHub Actions) e também em
`.gitlab-ci.yml` (GitLab). Ele **dispara sozinho a cada `git push`** e valida:

- **yamllint** + **ansible-lint** — qualidade do código YAML.
- **`ansible-playbook --syntax-check`** — sintaxe dos playbooks.
- **`terraform fmt -check`** + **`terraform validate`** — validação da infra.

Status atual: ![CI](https://github.com/arturstaation/TrabalhoIAC/actions/workflows/ci.yml/badge.svg)
(veja as execuções na aba **Actions** do repositório).

Para disparar o pipeline ao vivo (sem alterar nada), use um commit vazio:

```bash
git commit --allow-empty -m "demo: disparando o CI/CD"
git push
```

> Observação: a etapa de **deploy** do pipeline é **manual** e miraria um servidor
> acessível (a EC2). O servidor do GitHub não tem acesso ao seu Docker local, então o
> deploy no ambiente de teste é feito com `./testar-local.sh`. O enunciado pede que as
> alterações sejam **testadas automaticamente** — o que o CI faz a cada push.

## 9. Ansible Vault (gestão de segredos — Aula 5)

As senhas ficam em `inventory/group_vars/all/vault.yml`. **Criptografe** antes de subir:

```bash
ansible-vault encrypt inventory/group_vars/all/vault.yml   # criptografar
ansible-vault edit    inventory/group_vars/all/vault.yml   # editar
ansible-vault view    inventory/group_vars/all/vault.yml   # visualizar
```

Ao rodar os playbooks, informe a senha com `--ask-vault-pass` (ou `--vault-password-file`).

## 10. Mapeamento com o conteúdo das aulas

- **Aula 1** — Conceitos de IaC, boas práticas, estrutura de diretórios, versionamento.
- **Aula 2** — Terraform: `provider`, `resource`, `variable`, `output`, estado, `apply`.
- **Aula 3** — Ansible agentless via SSH, inventário INI, `ansible all -m ping`, ad-hoc.
- **Aula 4** — Playbooks (`hosts`, `become`, `tasks`), roles, handlers, templates Jinja2, `loop`.
- **Aula 5** — Segurança: Ansible Vault, hardening (firewall, serviços, política de senha).
- **Aula 6** — Inventário, variáveis (`vars`, `vars_files`, `group_vars`), CI/CD.
- **Aula 7** — Ansible Galaxy (`ansible-galaxy install`, `requirements.yml`), AWX.

## 11. Autor

**Artur Valladares** — Trabalho Final da disciplina de IaC.
