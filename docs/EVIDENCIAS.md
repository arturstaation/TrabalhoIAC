# Evidências de Execução

Execução real dos playbooks em um servidor Ubuntu 22.04 (container com systemd),
via `ansible-playbook playbooks/site.yml`. Todos os comandos foram executados de
verdade — as saídas abaixo são reais.

> Ambiente de teste: **Caminho B (Docker local)** do README. As mesmas roles rodam
> sem alteração em uma instância EC2 (Caminho A).

## Resultado final do playbook (PLAY RECAP)

```
PLAY RECAP *********************************************************************
servidor-linux : ok=48  changed=2  unreachable=0  failed=0  skipped=4  rescued=0  ignored=1
```

`failed=0` e execução **idempotente** (na 2ª execução quase tudo fica `ok`; as poucas
mudanças vêm da tarefa de backup, que por design roda o script a cada execução).

## Teste de conectividade (Aula 3)

```
$ ansible all -m ping
servidor-linux | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## 1. Usuário e grupo administrativo (Tarefa 1)

```
$ id deploy
uid=1000(deploy) gid=1001(deploy) groups=1001(deploy),27(sudo),1000(devops)
```

## 2. Firewall UFW (Tarefa 3 — Hardening)

```
$ ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # SSH
80/tcp                     ALLOW IN    Anywhere                   # HTTP
443/tcp                    ALLOW IN    Anywhere                   # HTTPS
9100/tcp                   ALLOW IN    Anywhere                   # Prometheus Node Exporter
```

## 3. fail2ban (Tarefa 3 — Hardening)

```
$ fail2ban-client status sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	0
|  `- Journal matches:	_SYSTEMD_UNIT=sshd.service + _COMM=sshd
`- Actions
   |- Currently banned:	0
   |- Total banned:	0
```

## 4. SSH Hardening (Tarefa 3)

```
$ grep -E "^(PermitRootLogin|AllowUsers|Banner)" /etc/ssh/sshd_config
PermitRootLogin no
Banner /etc/issue.net
AllowUsers deploy ubuntu
```

## 5. Política de senhas (Tarefa 3)

```
$ grep -E "^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)" /etc/login.defs
PASS_MAX_DAYS	90
PASS_MIN_DAYS	1
PASS_WARN_AGE	7

$ grep -E "^(minlen|dcredit|ucredit)" /etc/security/pwquality.conf
minlen = 14
dcredit = -1
ucredit = -1
```

## 6. Monitoramento — Node Exporter (Desafio)

```
$ systemctl is-active node_exporter
active

$ curl -s http://localhost:9100/metrics | grep node_cpu_seconds_total | head -3
node_cpu_seconds_total{cpu="0",mode="idle"} 519.54
node_cpu_seconds_total{cpu="0",mode="iowait"} 4.1
node_cpu_seconds_total{cpu="0",mode="irq"} 0
```

## 7. Backup e Recuperação (Desafio)

```
$ crontab -l | grep backup
30 2 * * * /usr/local/bin/backup-trabalho-iac.sh >> /var/log/backup-trabalho-iac.log 2>&1

$ ls -lh /var/backups/trabalho-iac/
-rw-r--r-- 1 root root 373K Jun 20 01:17 backup-20260620-011739.tar.gz
-rw-r--r-- 1 root root 373K Jun 20 01:19 backup-20260620-011923.tar.gz

# Saída do script de backup:
[Sat Jun 20 01:17:39 -03 2026] Iniciando backup de: /etc /home /var/www
[Sat Jun 20 01:17:39 -03 2026] Backup criado: /var/backups/trabalho-iac/backup-20260620-011739.tar.gz (376K)
[Sat Jun 20 01:17:39 -03 2026] Removendo backups com mais de 7 dias...
BACKUP_OK
```

## Como reproduzir

```bash
cd docker && docker compose up -d --build      # sobe o servidor de teste (systemd)
docker cp ../. servidor-linux:/root/trabalho-iac
docker exec servidor-linux bash -lc "apt-get update && apt-get install -y ansible"
docker exec servidor-linux bash -lc "cd /root/trabalho-iac && sed -i 's/ansible_connection=docker/ansible_connection=local/' inventory/hosts.ini && ansible-playbook playbooks/site.yml"
```
