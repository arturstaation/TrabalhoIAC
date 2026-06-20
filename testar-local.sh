#!/usr/bin/env bash
# ===========================================================================
# Testa o trabalho INTEIRO localmente no Docker, num comando só.
# Sobe um servidor Ubuntu 22.04 (com systemd), instala o Ansible nele e
# aplica todos os playbooks. Funciona no Git Bash (Windows), WSL, Linux e Mac.
#
# Uso:   ./testar-local.sh
# Pré-requisito: Docker Desktop aberto e rodando.
# ===========================================================================
set -euo pipefail

# Vai para a pasta do projeto (onde este script está)
cd "$(dirname "$0")"

CONTAINER="servidor-linux"

echo "==> [1/6] Verificando se o Docker está rodando..."
if ! docker info >/dev/null 2>&1; then
  echo "ERRO: Docker não está rodando. Abra o Docker Desktop e tente de novo."
  exit 1
fi

echo "==> [2/6] Subindo o servidor de teste (build + up)..."
docker compose -f docker/docker-compose.yml up -d --build

echo "==> [3/6] Aguardando o systemd ficar pronto dentro do container..."
for i in $(seq 1 20); do
  if docker exec "$CONTAINER" systemctl is-system-running >/dev/null 2>&1; then
    echo "    systemd OK."
    break
  fi
  sleep 2
done

echo "==> [4/6] Copiando o projeto e instalando o Ansible no servidor..."
docker cp . "$CONTAINER:/root/trabalho-iac"
docker exec "$CONTAINER" bash -lc '
  if ! command -v ansible >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y ansible >/tmp/ansible-install.log 2>&1
  fi
  ansible --version | head -1
'

echo "==> [5/6] Testando a conexão (ansible -m ping)..."
docker exec "$CONTAINER" bash -lc '
  cd /root/trabalho-iac
  # neste modo local, o Ansible roda DENTRO do servidor (conexão local)
  sed -i "s/ansible_connection=docker/ansible_connection=local/" inventory/hosts.ini
  ansible all -m ping
'

echo "==> [6/6] Aplicando TODOS os playbooks (site.yml)..."
docker exec "$CONTAINER" bash -lc 'cd /root/trabalho-iac && ansible-playbook playbooks/site.yml'

echo ""
echo "============================================================"
echo " PRONTO! Para ver as evidências rodando, use:"
echo ""
echo "   docker exec $CONTAINER ufw status verbose"
echo "   docker exec $CONTAINER fail2ban-client status sshd"
echo "   docker exec $CONTAINER curl -s localhost:9100/metrics | head"
echo "   docker exec $CONTAINER ls -lh /var/backups/trabalho-iac/"
echo ""
echo " Para abrir um shell no servidor:  docker exec -it $CONTAINER bash"
echo " Para derrubar tudo:               docker compose -f docker/docker-compose.yml down"
echo "============================================================"
