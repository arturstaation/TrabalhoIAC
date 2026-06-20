# 🎤 Guia Completo de Apresentação — Trabalho Final de IaC

**Aluno:** Artur Valladares · **Disciplina:** Infrastructure as Code · **Prof.:** Felipe Gualdi
**Repositório:** https://github.com/arturstaation/TrabalhoIAC

Este é o **roteiro único** para apresentar. Siga de cima para baixo. Cada seção tem:
o que falar, qual arquivo abrir, qual comando rodar e o que aquilo prova.

---

## 📋 PARTE 0 — Preparação (faça 5 min antes)

1. Abra o **Docker Desktop** e espere ficar *running*.
2. No **Git Bash**, dentro da pasta do projeto, garanta o ambiente no ar:
   ```bash
   cd "/c/Users/artur/OneDrive/Área de Trabalho/IAC/trabalho-iac"
   docker ps --filter name=servidor-linux        # se aparecer "Up", está pronto
   # se NÃO estiver no ar, suba do zero (~3-4 min):
   ./testar-local.sh
   ```
3. Deixe abertas estas abas no navegador:
   - GitHub: https://github.com/arturstaation/TrabalhoIAC
   - GitHub Actions: https://github.com/arturstaation/TrabalhoIAC/actions
   - http://localhost:8080 (página do servidor)
   - http://localhost:8080/produtos.html (front dos produtos)
   - http://localhost:9100/metrics (métricas)
4. Deixe este arquivo e o `docs/EVIDENCIAS.md` abertos para consulta.

---

## 📖 O QUE O TRABALHO PEDE (requisitos)

**Cenário:** automatizar a infraestrutura de uma pequena empresa (servidores Linux,
rede, segurança) usando **Terraform e Ansible**.

| # | Requisito | Tipo |
|---|-----------|------|
| 1 | **Configuração Inicial** — instalar pacotes, configurar usuários/grupos e segurança básica | Obrigatório |
| 2 | **Gerenciamento de Pacotes** — instalar, atualizar e remover pacotes | Obrigatório |
| 3 | **Hardening de Segurança** — firewall, desativar serviços, política de senha | Obrigatório |
| 4 | **Integração Contínua (CI/CD)** — testar/implantar mudanças automaticamente | Obrigatório |
| 5 | **Monitoramento e Logging** — ferramentas de monitoração e centralização de logs | Desafio |
| 6 | **Backup e Recuperação** — backups regulares + procedimento de recuperação | Desafio |

> **Extra (além do pedido):** provisionamento com Terraform (AWS), gestão de segredos
> com Ansible Vault, e uma aplicação de exemplo (API Python + SQLite + front) implantada
> via Ansible — para demonstrar o ciclo completo de deploy.

---

## 🗣️ PARTE 1 — Abertura (30 segundos)

> *"Meu trabalho automatiza toda a infraestrutura de uma empresa usando Infrastructure
> as Code. Com **Terraform** eu provisiono o servidor; com **Ansible** eu configuro ele
> inteiro — usuários, pacotes, segurança, monitoramento, backup — e ainda implanto uma
> aplicação. Tudo é código, versionado no Git, e posso recriar o ambiente do zero com
> um comando. Vou mostrar funcionando."*

---

## 🗂️ PARTE 2 — Visão geral do projeto (no GitHub)

**Abra o repositório e mostre o README.** Fale:

> *"O projeto é modular, seguindo o que vimos em aula. Cada pasta tem uma
> responsabilidade:"*

| Pasta/arquivo | O que é | Aula |
|---------------|---------|------|
| `terraform/` | Provisiona a máquina na AWS (VPC, EC2, firewall) | 2 |
| `inventory/` | Lista de servidores + variáveis + segredos (Vault) | 3, 5, 6 |
| `playbooks/` | Orquestra a execução (`site.yml` chama as roles) | 4 |
| `roles/` | Configuração dividida por responsabilidade | 4 |
| `.github/workflows/` | Pipeline de CI/CD | 6 |
| `docker/` | Ambiente de teste local (Ubuntu + systemd) | — |
| `docs/` | Relatório, evidências e este guia | — |

> *"O ponto central: o Terraform cria o servidor e gera sozinho o inventário do Ansible.
> Aí o Ansible se conecta por SSH — sem instalar agente — e aplica as roles, que
> descrevem o estado desejado de forma declarativa."*

---

## ⚙️ PARTE 3 — Demonstrar cada requisito

> Dica: para os comandos não terem o caminho convertido pelo Git Bash, todos usam
> `docker exec servidor-linux bash -lc "..."`.

### ✅ Requisito 1 — Configuração Inicial
**Arquivo a exibir:** `roles/configuracao_inicial/tasks/main.yml`

> *"Esta role faz a configuração inicial: instala pacotes base, define fuso horário, e
> cria o usuário administrativo `deploy` no grupo `devops` com acesso sudo e chave SSH."*

```bash
docker exec servidor-linux id deploy
```
**Prova:** `uid=1000(deploy) ... groups=27(sudo),1000(devops)` — usuário e grupo criados.

### ✅ Requisito 2 — Gerenciamento de Pacotes
**Arquivo a exibir:** `roles/gerenciamento_pacotes/tasks/main.yml`

> *"Aqui eu gerencio pacotes em três estados: instalo (nginx), atualizo (state latest) e
> removo os inseguros — o telnet, por exemplo, foi removido."*

```bash
docker exec servidor-linux bash -lc "dpkg -l | grep -E '^ii  (nginx|telnet)' || echo 'telnet removido ✓'"
```
**Prova:** nginx presente, telnet ausente.

### ✅ Requisito 3 — Hardening de Segurança
**Arquivo a exibir:** `roles/hardening/tasks/main.yml`

> *"A role de hardening aplica firewall, desativa serviços não usados, endurece o SSH e
> define política de senha forte, além de instalar o fail2ban."*

```bash
docker exec servidor-linux ufw status verbose
docker exec servidor-linux fail2ban-client status sshd
docker exec servidor-linux bash -lc "grep -E '^(PermitRootLogin|AllowUsers)' /etc/ssh/sshd_config"
docker exec servidor-linux bash -lc "grep -E '^(PASS_MAX_DAYS|minlen)' /etc/login.defs /etc/security/pwquality.conf"
```
**Prova:** firewall ativo (deny + portas liberadas), fail2ban monitorando o SSH, root sem
login, senha com validade e tamanho mínimo.

### ✅ Requisito 4 — Integração Contínua (CI/CD)
**Arquivo a exibir:** `.github/workflows/ci.yml`
**Aba a abrir:** GitHub → **Actions** (mostre tudo verde ✓)

> *"A cada push no Git, esse pipeline valida automaticamente o Terraform e os playbooks:
> faz lint, syntax-check e terraform validate. Posso disparar agora ao vivo."*

```bash
git commit --allow-empty -m "demo: disparando o CI/CD"
git push
```
Atualize a aba **Actions** → o workflow roda do zero e fica verde em ~45s.
**Prova:** pipeline automático validando a infraestrutura.

### ⭐ Requisito 5 — Monitoramento e Logging
**Arquivo a exibir:** `roles/monitoramento/tasks/main.yml`
**Abra no navegador:** http://localhost:9100/metrics

> *"Instalei o Prometheus Node Exporter, que expõe métricas de CPU, memória e disco do
> servidor. O logging usa rsyslog e logrotate."*

```bash
docker exec servidor-linux systemctl is-active node_exporter
docker exec servidor-linux bash -lc "curl -s localhost:9100/metrics | grep -E '^node_(memory_MemTotal|cpu_seconds)' | head -3"
```
**Prova:** serviço ativo e métricas reais sendo expostas.

### ⭐ Requisito 6 — Backup e Recuperação
**Arquivo a exibir:** `roles/backup/tasks/main.yml` e `roles/backup/templates/backup.sh.j2`

> *"Criei um script que faz backup compactado dos diretórios críticos, agendado no cron
> diariamente, com retenção de 7 dias, e um script separado para restauração."*

```bash
docker exec servidor-linux bash -lc "ls -lh /var/backups/trabalho-iac/ && echo '--- cron ---' && crontab -l"
```
**Prova:** arquivo `.tar.gz` gerado + agendamento no cron.

---

## 🌐 PARTE 4 — Aplicação de exemplo (o diferencial visual)

> *"Para mostrar o ciclo completo de IaC — não só configurar, mas também implantar uma
> aplicação — o Ansible sobe uma API em Python com um banco SQLite que nasce populado, e
> um front-end que consome essa API."*

**Arquivos a exibir:** `roles/aplicacao/templates/app.py.j2` (a API) e
`roles/aplicacao/templates/produtos.html.j2` (o front).

**Abra no navegador, em ordem:**
1. http://localhost:8080 → página do servidor provisionado
2. http://localhost:8080/produtos.html → **catálogo de produtos** (cards)
3. http://localhost:8080/api/produtos → o JSON cru da API

```bash
# mostrar que o banco está realmente no servidor, populado:
docker exec servidor-linux sqlite3 /opt/app/dados.db "SELECT * FROM produtos;"
```
**Prova:** front → API → banco, tudo implantado por Ansible e funcionando.

---

## 🔁 PARTE 5 — Fechamento: reprodutibilidade (momento mais forte)

> *"O princípio central de IaC é que tudo é código. Se eu rodar os playbooks duas vezes,
> o resultado é o mesmo — isso é idempotência. E se o servidor for perdido, eu recrio um
> idêntico do zero com um comando."*

Se sobrar tempo, faça ao vivo:
```bash
docker compose -f docker/docker-compose.yml down -v   # destrói tudo
./testar-local.sh                                      # recria do zero (~3-4 min)
```

> *"Entreguei as 4 tarefas obrigatórias e os 2 desafios, tudo testado, versionado no Git
> e validado por um pipeline de CI/CD. Obrigado."*

---

## ❓ PARTE 6 — Perguntas prováveis (respostas prontas)

| Pergunta | Resposta curta |
|----------|----------------|
| O que é idempotência? | Rodar o playbook N vezes leva ao mesmo estado; só muda o que está fora do desejado. |
| Declarativo ou imperativo? | Declarativo: descrevo o estado desejado, a ferramenta decide como chegar. |
| Por que Ansible é agentless? | Conecta via SSH, não exige agente instalado no servidor (Aula 3). |
| Onde ficam as senhas? | Em `vault.yml`, criptografado com Ansible Vault; nunca em texto puro (Aula 5). |
| Como Terraform fala com Ansible? | Ao criar a EC2, gera o `inventory/hosts.ini` (recurso `local_file`). |
| E se o hardening quebrar o SSH? | Uso `validate: sshd -t` antes de aplicar; não dá para se trancar para fora. |
| Por que não Nagios/ELK? | O enunciado deixa livre; escolhi stack leve (Node Exporter) 100% via Ansible. |
| O CI faz deploy no seu Docker? | Não — o runner do GitHub não acessa meu PC. O CI valida; o deploy local é via `testar-local.sh`. Não é requisito. |
| Roda na AWS de verdade? | Sim — `terraform apply` cria a EC2. Testei no Docker para não gerar custo; as roles são idênticas. |

---

## 📁 PARTE 7 — Mapa de arquivos para exibir (cola rápida)

| Se ele pedir... | Abra este arquivo |
|-----------------|-------------------|
| O provisionamento | `terraform/main.tf` |
| Como o inventário é gerado | final do `terraform/main.tf` (recurso `local_file`) |
| O playbook principal | `playbooks/site.yml` |
| Configuração inicial | `roles/configuracao_inicial/tasks/main.yml` |
| Gerenciamento de pacotes | `roles/gerenciamento_pacotes/tasks/main.yml` |
| Hardening | `roles/hardening/tasks/main.yml` |
| Firewall (template) | `roles/hardening/templates/jail.local.j2` |
| Monitoramento | `roles/monitoramento/tasks/main.yml` |
| Backup | `roles/backup/tasks/main.yml` |
| Script de restauração | `roles/backup/templates/restore.sh.j2` |
| A API | `roles/aplicacao/templates/app.py.j2` |
| O front | `roles/aplicacao/templates/produtos.html.j2` |
| Variáveis do projeto | `inventory/group_vars/all/vars.yml` |
| Segredos (Vault) | `inventory/group_vars/all/vault.yml` |
| CI/CD | `.github/workflows/ci.yml` |
| Evidências (provas) | `docs/EVIDENCIAS.md` |

---

## ✅ CHECKLIST FINAL (antes de entrar)

- [ ] Docker Desktop *running*.
- [ ] `docker ps` mostra `servidor-linux` *Up* (ou rodei `./testar-local.sh`).
- [ ] http://localhost:8080 abre.
- [ ] http://localhost:8080/produtos.html mostra os produtos.
- [ ] http://localhost:9100/metrics responde.
- [ ] Abas do GitHub (repo + Actions) abertas.
- [ ] Este guia e `docs/EVIDENCIAS.md` abertos.
