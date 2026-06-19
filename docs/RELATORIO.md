# Relatório — Trabalho Final de Infrastructure as Code (IaC)

**Aluno:** Artur Valladares
**Disciplina:** Infrastructure as Code (IaC)
**Professor:** Felipe Gualdi — Universidade Presbiteriana Mackenzie (FCI)
**Ferramentas:** Terraform + Ansible

---

## 1. Introdução

Este trabalho automatiza, de ponta a ponta, o gerenciamento da infraestrutura de uma
pequena empresa com servidores Linux. Toda a infraestrutura é tratada **como código**
(IaC), de forma **declarativa**, **versionada em Git** e **reprodutível** entre
ambientes — exatamente os princípios apresentados na Aula 1.

A solução combina as duas ferramentas centrais do curso:

- **Terraform** (Aula 2) — provisiona a máquina (instância EC2 na AWS) e toda a rede.
- **Ansible** (Aulas 3 a 7) — configura o servidor por meio de **playbooks** e **roles**.

## 2. Arquitetura da solução

```
                    ┌──────────────────┐
                    │   Git / GitHub   │  ← versionamento (Aula 1)
                    └────────┬─────────┘
                             │ push → dispara CI/CD (Aula 6)
                             ▼
        ┌───────────────────────────────────────────┐
        │  Nó de Controle (seu PC / WSL2)            │
        │  - Terraform  →  provisiona a infra na AWS │
        │  - Ansible    →  configura via SSH         │
        └───────────────┬─────────────────┬─────────┘
                        │                 │
              terraform apply       ansible-playbook
                        │                 │ (agentless, SSH - Aula 3)
                        ▼                 ▼
        ┌───────────────────────────────────────────┐
        │   Servidor Linux alvo (EC2 ou container)   │
        │   roles: configuracao_inicial, pacotes,    │
        │          hardening, monitoramento, backup  │
        └───────────────────────────────────────────┘
```

O Terraform, ao criar a EC2, **gera automaticamente o inventário do Ansible**
(`inventory/hosts.ini`), conectando as duas ferramentas sem passo manual.

## 3. Decisões de projeto

| Decisão | Justificativa |
|---------|---------------|
| **Modularização em roles** | Boa prática de arquitetura da Aula 1 e estrutura de roles da Aula 4: cada role tem responsabilidade única, é reutilizável e fácil de manter. |
| **Variáveis centralizadas em `group_vars`** | Parametrização (Aula 6): trocar comportamento sem editar tasks. |
| **Ansible Vault para senhas** | Gestão de segredos da Aula 5: nada de credencial em texto puro no Git. |
| **Dois alvos (AWS EC2 e Docker local)** | AWS é fiel à Aula 2; Docker permite testar de graça e validar antes do deploy. |
| **Node Exporter + rsyslog** em vez de Nagios/ELK | O enunciado permite escolha livre de ferramentas; optou-se por uma stack leve, 100% instalável via Ansible, sem dependências pesadas. |
| **Handlers com `notify`** | Serviços (SSH, fail2ban, node_exporter) só reiniciam quando há mudança real — Aula 4. |
| **`validate: sshd -t -f %s`** | Ao alterar o `sshd_config`, valida a config antes de aplicar para não perder o acesso — boa prática de hardening (Aula 5). |

## 4. Implementação das tarefas

### Tarefa 1 — Configuração Inicial (`roles/configuracao_inicial`)
- Atualização do cache APT e definição de fuso horário.
- Instalação de pacotes base (`curl`, `vim`, `git`, `htop`, ...) via `loop` (Aula 4).
- Criação de **grupo** e **usuário** administrativo (módulos `group`/`user`, Aula 4).
- `sudo` sem senha para o grupo `devops` (com `validate: visudo`).
- Autorização da **chave SSH** do admin e banner legal de acesso.

### Tarefa 2 — Gerenciamento de Pacotes (`roles/gerenciamento_pacotes`)
- **Instalar** (`state: present`), **atualizar** (`state: latest`) e **remover**
  (`state: absent` + `purge`) pacotes — listas parametrizadas em `group_vars`.
- Upgrade completo opcional do sistema (`upgrade: dist`).
- Detecção de necessidade de reboot.

### Tarefa 3 — Hardening de Segurança (`roles/hardening`)
Implementa exatamente os itens do slide 43 da Aula 5:
- **Firewall UFW**: política padrão `deny` na entrada, liberando só as portas necessárias.
- **Desativação de serviços** não utilizados (`avahi-daemon`, `cups`, `rpcbind`).
- **SSH hardening**: sem root login, sem senha (só chave), `AllowUsers`, banner.
- **Política de senhas**: `login.defs` (validade) + `pwquality` (complexidade mínima).
- **fail2ban** contra brute-force, configurado por template Jinja2.

### Tarefa 4 — Integração Contínua (`.gitlab-ci.yml` e `.github/workflows/ci.yml`)
Pipeline com estágios **lint → validate → deploy**:
- `yamllint` + `ansible-lint` (qualidade do código).
- `ansible-playbook --syntax-check` (valida os playbooks).
- `terraform fmt -check` + `terraform validate` (valida a infra).
- Deploy manual na branch `main`, com a senha do Vault vinda de variável protegida.

### Tarefa 5 (Desafio) — Monitoramento e Logging (`roles/monitoramento`)
- **Monitoramento**: Prometheus **Node Exporter** como serviço systemd, expondo
  métricas em `:9100/metrics` (CPU, memória, disco, rede).
- **Logging**: `rsyslog` (com encaminhamento remoto opcional) e `logrotate`
  para rotação dos logs.

### Tarefa 6 (Desafio) — Backup e Recuperação (`roles/backup`)
- Script de **backup** (`tar.gz`) dos diretórios críticos, com **retenção** configurável.
- Agendamento diário via **cron** (módulo `cron`).
- Script de **restauração** para recuperação em caso de falha.

## 5. Como executar (resumo)

```bash
# 0) Dependências
ansible-galaxy collection install -r requirements.yml

# 1a) AWS (Terraform provisiona)        | 1b) Docker local (gratuito)
cd terraform                            | cd docker
cp terraform.tfvars.example \           | docker compose up -d
   terraform.tfvars                     | cd ..
terraform init && terraform apply       |
cd ..                                   |

# 2) Criptografar segredos (Aula 5)
ansible-vault encrypt inventory/group_vars/all/vault.yml

# 3) Testar conexão e aplicar tudo
ansible all -m ping
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## 6. Evidências sugeridas para a entrega

Para comprovar o funcionamento, recomenda-se anexar prints de:
1. `terraform apply` concluído (ou `docker compose up`).
2. `ansible all -m ping` retornando `pong`.
3. `ansible-playbook playbooks/site.yml` com o `PLAY RECAP` em verde.
4. `sudo ufw status` mostrando as regras de firewall.
5. `curl http://localhost:9100/metrics` (Node Exporter respondendo).
6. `sudo fail2ban-client status sshd`.
7. Listagem de `/var/backups/trabalho-iac/` com o `.tar.gz` gerado.
8. Pipeline de CI/CD verde no GitHub/GitLab.

## 7. Mapeamento com as aulas

| Aula | Conteúdo | Onde aparece no trabalho |
|------|----------|--------------------------|
| 1 | Conceitos de IaC, boas práticas, estrutura de diretórios, Git | Organização do repositório, `.gitignore`, README |
| 2 | Terraform (provider, resource, variable, output, state) | `terraform/` |
| 3 | Ansible agentless, inventário INI, `ping`, ad-hoc | `inventory/`, `ansible all -m ping` |
| 4 | Playbooks, roles, handlers, templates, `loop` | `playbooks/`, `roles/` |
| 5 | Vault, hardening (firewall/serviços/senha) | `roles/hardening`, `vault.yml` |
| 6 | Inventário, variáveis (`group_vars`), CI/CD | `group_vars/`, `.gitlab-ci.yml` |
| 7 | Ansible Galaxy, AWX | `requirements.yml`, seção AWX abaixo |

## 8. Observação sobre AWX (Aula 7)

Embora não seja exigido instalar o AWX para este trabalho, o repositório está pronto
para ser gerenciado por ele: bastaria, no AWX, criar um **Projeto** apontando para este
repositório Git, configurar **Credenciais** (SSH + Vault), importar os **playbooks** e
criar **Job Templates** para `site.yml` — exatamente o fluxo demonstrado na Aula 7.

## 9. Conclusão

O trabalho cumpre as 4 tarefas obrigatórias e os 2 itens do desafio, aplicando os
conceitos de IaC declarativa, modularização, versionamento, segurança e automação
vistos ao longo do curso. A solução é reprodutível tanto na nuvem (AWS) quanto
localmente (Docker), e validada automaticamente por um pipeline de CI/CD.
