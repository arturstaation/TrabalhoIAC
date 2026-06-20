# 🎤 Guia de Apresentação — Trabalho Final de IaC

Guia prático para apresentar o trabalho, mostrar que funciona e responder o professor.
Leia isto na véspera. Tudo aqui foi testado de verdade.

---

## ⏱️ TL;DR — o que fazer na hora

1. Abra o **Docker Desktop** e espere ficar "running".
2. No Git Bash, dentro da pasta do projeto:
   ```bash
   # (opcional) zerar tudo para mostrar do ZERO
   docker compose -f docker/docker-compose.yml down -v

   # sobe e configura o servidor inteiro (~3-4 min)
   ./testar-local.sh
   ```
3. Abra no navegador: **http://localhost:8080** e **http://localhost:9100/metrics**
4. Mostre as evidências no terminal (seção 4 abaixo).

> Subir do zero leva **~3min30s** (medido). Faça isso ANTES da aula começar se quiser
> chegar com tudo pronto, ou ao vivo se quiser mostrar o provisionamento acontecendo.

---

## 1. O que é o trabalho (resumo de 30 segundos para falar)

> "É a automação completa da infraestrutura de uma empresa usando **Infrastructure as
> Code**. Com **Terraform** eu provisiono o servidor (uma EC2 na AWS) e com **Ansible**
> eu configuro tudo nele — usuários, pacotes, segurança, monitoramento e backup — de
> forma **declarativa, versionada no Git e reproduzível**. Posso destruir e recriar o
> ambiente inteiro do zero com um comando."

As **6 entregas** (4 obrigatórias + 2 desafios):

| # | Entrega | Role/arquivo |
|---|---------|--------------|
| 1 | Configuração inicial | `roles/configuracao_inicial` |
| 2 | Gerenciamento de pacotes | `roles/gerenciamento_pacotes` |
| 3 | Hardening de segurança | `roles/hardening` |
| 4 | CI/CD | `.gitlab-ci.yml`, `.github/workflows/ci.yml` |
| 5 | Monitoramento e logging (desafio) | `roles/monitoramento` |
| 6 | Backup e recuperação (desafio) | `roles/backup` |

---

## 2. Como TESTAR tudo

### Opção A — um comando (recomendado)
```bash
./testar-local.sh
```
Sobe o container, instala o Ansible e aplica todos os playbooks. No final mostra as URLs.

### Opção B — passo a passo (se o professor quiser ver cada etapa)
```bash
# 1. sobe o servidor (Ubuntu 22.04 com systemd)
docker compose -f docker/docker-compose.yml up -d --build

# 2. copia o projeto e instala o Ansible no servidor
docker cp . servidor-linux:/root/trabalho-iac
docker exec servidor-linux bash -lc "apt-get update && apt-get install -y ansible"

# 3. testa a conexão (Aula 3)
docker exec servidor-linux bash -lc "cd /root/trabalho-iac && sed -i 's/ansible_connection=docker/ansible_connection=local/' inventory/hosts.ini && ansible all -m ping"

# 4. aplica TODOS os playbooks
docker exec servidor-linux bash -lc "cd /root/trabalho-iac && ansible-playbook playbooks/site.yml"

# 5. (alternativa) aplicar só uma parte usando tags
docker exec servidor-linux bash -lc "cd /root/trabalho-iac && ansible-playbook playbooks/site.yml --tags hardening"
```

**Resultado esperado:** `PLAY RECAP ... ok=53 changed=... failed=0`. O **`failed=0`** é a prova
de que rodou tudo certo. Se rodar 2x, a maioria vira `ok` (idempotência — característica
central de IaC, vale citar).

---

## 3. O que APRESENTAR (roteiro sugerido, ~7 min)

1. **Abrir o repositório no GitHub** — mostrar a estrutura de pastas (Terraform, roles,
   playbooks, CI/CD). Falar de versionamento (Aula 1).
2. **Mostrar um playbook e uma role** — abrir `playbooks/site.yml` e
   `roles/hardening/tasks/main.yml`. Explicar `hosts`, `become`, `tasks`, `loop`, handlers.
3. **Rodar `./testar-local.sh`** (ou mostrar já rodado) — apontar o `failed=0`.
4. **Abrir o navegador**: `http://localhost:8080` (página gerada pelo Ansible) e
   `http://localhost:9100/metrics` (monitoramento).
5. **Mostrar evidências no terminal** (seção 4): usuário, firewall, fail2ban, backup.
6. **Mostrar o CI/CD** — a aba **Actions** no GitHub validando o código a cada push.
7. **Fechar** falando da reprodutibilidade: "posso destruir e recriar do zero" (seção 6).

---

## 4. Como MOSTRAR as EVIDÊNCIAS (copia e cola)

> Dica: use `docker exec servidor-linux bash -lc "..."` para evitar que o Git Bash
> converta os caminhos (`/var/...` vira `C:/Program Files/Git/var/...`).

```bash
# 1) USUÁRIO e GRUPO criados (Tarefa 1)
docker exec servidor-linux id deploy
#   -> uid=1000(deploy) ... groups=27(sudo),1000(devops)

# 2) PACOTES: nginx instalado, telnet removido (Tarefa 2)
docker exec servidor-linux bash -lc "dpkg -l | grep -E 'nginx|telnet' || echo 'telnet removido'"

# 3) FIREWALL ativo (Tarefa 3)
docker exec servidor-linux ufw status verbose

# 4) SSH endurecido (Tarefa 3)
docker exec servidor-linux bash -lc "grep -E '^(PermitRootLogin|AllowUsers|Banner)' /etc/ssh/sshd_config"

# 5) POLÍTICA DE SENHA (Tarefa 3)
docker exec servidor-linux bash -lc "grep -E '^(PASS_MAX_DAYS|minlen)' /etc/login.defs /etc/security/pwquality.conf"

# 6) FAIL2BAN protegendo o SSH (Tarefa 3)
docker exec servidor-linux fail2ban-client status sshd

# 7) MONITORAMENTO — Node Exporter (Desafio 5)
docker exec servidor-linux systemctl is-active node_exporter
#   no navegador: http://localhost:9100/metrics

# 8) BACKUP gerado + agendado (Desafio 6)
docker exec servidor-linux bash -lc "ls -lh /var/backups/trabalho-iac/ && crontab -l"

# 9) RECUPERAÇÃO — script de restore
docker exec servidor-linux cat /usr/local/bin/restore-trabalho-iac.sh
```

As mesmas saídas, já capturadas, estão em **`docs/EVIDENCIAS.md`** — bom ter aberto como backup.

---

## 5. Explicação do CÓDIGO (para você consultar e explicar cada playbook)

> Todo arquivo `.yml` já tem comentários explicando cada tarefa e citando a aula.
> Abaixo, a versão "em português de gente" para você falar com segurança.

### `terraform/` — provisiona a máquina (Aula 2)
- **O que é:** define a infra na AWS de forma declarativa. Cria VPC → sub-rede →
  internet gateway → tabela de rotas → security group → instância EC2.
- **Por quê:** é a parte "Terraform" do trabalho. Cria o servidor onde o Ansible vai atuar.
- **Detalhe esperto:** ao criar a EC2, um recurso `local_file` **gera o inventário do
  Ansible automaticamente** (`inventory/hosts.ini`) — conecta as duas ferramentas.
- **Comandos:** `terraform init` → `plan` → `apply` (e `destroy` para remover).

### `inventory/` — quem o Ansible gerencia (Aulas 3 e 6)
- **`hosts.ini`:** lista os servidores (formato INI). Tem o grupo `aws` (EC2) e `local`
  (container de teste).
- **`group_vars/all/vars.yml`:** todas as variáveis públicas (listas de pacotes, portas
  do firewall, política de senha…). Mudar comportamento sem editar as tasks.
- **`group_vars/all/vault.yml`:** **segredos** (senhas) — criptografado com **Ansible
  Vault** (Aula 5).

### `playbooks/` — o que executar (Aula 4)
- **`site.yml`:** o playbook principal — chama as 5 roles na ordem.
- **`01..05-*.yml`:** um playbook por tarefa, para rodar isolado se quiser.
- **Conceitos:** `hosts: servidores` (onde roda), `become: true` (vira root/sudo),
  `roles:` (quais roles aplicar).

### `roles/configuracao_inicial` — Tarefa 1
- Atualiza pacotes, define fuso horário, instala pacotes base com **`loop`**, cria o
  **grupo `devops`** e o **usuário `deploy`** (módulos `group`/`user`), dá sudo,
  autoriza a chave SSH e põe um banner de aviso. Garante o SSH ativo.

### `roles/gerenciamento_pacotes` — Tarefa 2
- **Instala** (`state: present`), **atualiza** (`state: latest` + upgrade) e **remove**
  (`state: absent`) pacotes — tudo por listas em `vars.yml`. Inicia o nginx e publica a
  página de demonstração (template Jinja2).

### `roles/hardening` — Tarefa 3 (a mais importante de segurança — Aula 5)
- **UFW:** firewall com política padrão **negar entrada** e libera só 22/80/443/9100.
- **Serviços:** desativa avahi/cups/rpcbind (módulo `systemd`).
- **SSH:** desabilita login de root, exige chave, restringe usuários (`lineinfile`
  com `validate: sshd -t` para não se trancar para fora).
- **Senha:** validade e complexidade mínimas (`login.defs` + `pwquality`).
- **fail2ban:** bane IPs que erram a senha do SSH (template `jail.local.j2`).
- **Handlers + notify:** o SSH/fail2ban só reinicia quando algo muda de fato.

### `roles/monitoramento` — Desafio (Aula 5/6)
- **Monitoramento:** instala o **Prometheus Node Exporter** como serviço systemd,
  expondo métricas em `:9100/metrics`.
- **Logging:** `rsyslog` (encaminhamento opcional) + `logrotate` (rotação).
- *Por que não Nagios/ELK?* O enunciado deixa livre; escolhi uma stack leve, 100%
  instalável via Ansible, sem dependências pesadas.

### `roles/backup` — Desafio
- Script de **backup** (`.tar.gz` de `/etc`, `/home`, `/var/www`), agendado via **cron**
  (02:30), com **retenção** de 7 dias, e um script de **restore** para recuperação.

### `.gitlab-ci.yml` / `.github/workflows/ci.yml` — Tarefa 4 (CI/CD)
- Pipeline com estágios **lint → validate → deploy**: `yamllint`, `ansible-lint`,
  `ansible-playbook --syntax-check` e `terraform validate`. Roda sozinho a cada push.

### `docker/` — ambiente de teste local
- `Dockerfile` + `docker-compose.yml` sobem um Ubuntu 22.04 **com systemd** (necessário
  para UFW, fail2ban e os serviços), expondo as portas 8080 e 9100. É só para testar
  sem gastar na AWS.

---

## 6. Como DELETAR e SUBIR DO ZERO (demo de reprodutibilidade)

Esse é o momento mais forte da apresentação — prova que é IaC de verdade.

```bash
# 1. DESTRÓI o ambiente inteiro
docker compose -f docker/docker-compose.yml down -v

# 2. confirma que não existe mais
docker ps -a --filter name=servidor-linux

# 3. RECRIA tudo do zero, configurado, em ~3-4 min
./testar-local.sh
```

> Frase para falar: *"Toda a infraestrutura é código. Se o servidor for perdido, eu
> recrio um idêntico do zero com um comando — sem configurar nada na mão. Isso é
> reprodutibilidade, um dos princípios centrais de IaC."*

Na AWS o equivalente seria:
```bash
cd terraform && terraform destroy      # remove a EC2 e toda a rede
terraform apply                        # recria do zero
```

---

## 7. Perguntas que o professor pode fazer (e respostas)

- **"O que é idempotência?"** → Rodar o playbook várias vezes leva ao mesmo estado;
  ele só muda o que está fora do desejado. Por isso na 2ª execução quase tudo fica `ok`.
- **"Declarativo ou imperativo?"** → Declarativo: eu descrevo o estado desejado (ex.:
  "pacote presente", "porta liberada") e a ferramenta decide como chegar lá.
- **"Por que Ansible é agentless?"** → Ele se conecta via SSH e não exige agente
  instalado no servidor (Aula 3).
- **"Onde ficam as senhas?"** → Em `vault.yml`, criptografado com Ansible Vault; nunca
  em texto puro no Git (Aula 5).
- **"Como o Terraform fala com o Ansible?"** → O Terraform gera o `hosts.ini` do Ansible
  ao criar a EC2 (recurso `local_file`).
- **"E se quebrar o SSH no hardening?"** → Uso `validate: sshd -t` antes de aplicar, e
  só desativo senha quando há chave configurada — não dá para se trancar para fora.
- **"Por que rodou o Ansible dentro do container?"** → Como não há Ansible no Windows,
  no teste local ele roda de dentro do servidor (conexão local). Na AWS roda do PC via
  SSH. As roles e o resultado são idênticos.

---

## 8. Checklist final antes de apresentar

- [ ] Docker Desktop aberto e "running".
- [ ] `./testar-local.sh` rodou e deu **`failed=0`**.
- [ ] `http://localhost:8080` abre a página.
- [ ] `http://localhost:9100/metrics` responde.
- [ ] Repositório no GitHub aberto numa aba.
- [ ] `docs/EVIDENCIAS.md` e este guia abertos para consulta.
- [ ] Aba **Actions** do GitHub mostrando o CI verde.
