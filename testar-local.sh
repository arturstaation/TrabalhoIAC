#!/usr/bin/env bash
# ===========================================================================
# Testa o trabalho localmente no Docker, num comando só.
# Sobe um servidor Ubuntu 22.04 (com systemd), instala o Ansible nele e
# aplica os playbooks. Funciona no Git Bash (Windows), WSL, Linux e Mac.
#
# Uso:
#   ./testar-local.sh                 # roda TUDO (playbooks/site.yml)
#   ./testar-local.sh 01              # roda só a etapa 1 (configuração inicial)
#   ./testar-local.sh 03              # roda só a etapa 3 (hardening)
#   ./testar-local.sh hardening       # roda só por tag (ex.: hardening)
#
# Etapas:  01=config inicial  02=pacotes  03=hardening
#          04=monitoramento   05=backup   06=aplicação (API+front)
#
# Pré-requisito: Docker Desktop aberto e rodando.
# ===========================================================================
set -euo pipefail

# Vai para a pasta do projeto (onde este script está)
cd "$(dirname "$0")"

CONTAINER="servidor-linux"

# --- Descobre o que rodar a partir do argumento opcional ---
ARG="${1:-}"
case "$ARG" in
  "")                  PLAYBOOK="playbooks/site.yml"; EXTRA=""; DESC="TODOS os playbooks" ;;
  01) PLAYBOOK="playbooks/01-configuracao-inicial.yml"; EXTRA=""; DESC="etapa 1 (configuração inicial)" ;;
  02) PLAYBOOK="playbooks/02-gerenciamento-pacotes.yml"; EXTRA=""; DESC="etapa 2 (gerenciamento de pacotes)" ;;
  03) PLAYBOOK="playbooks/03-hardening.yml"; EXTRA=""; DESC="etapa 3 (hardening)" ;;
  04) PLAYBOOK="playbooks/04-monitoramento.yml"; EXTRA=""; DESC="etapa 4 (monitoramento)" ;;
  05) PLAYBOOK="playbooks/05-backup.yml"; EXTRA=""; DESC="etapa 5 (backup)" ;;
  06) PLAYBOOK="playbooks/06-aplicacao.yml"; EXTRA=""; DESC="etapa 6 (aplicação)" ;;
  *)  PLAYBOOK="playbooks/site.yml"; EXTRA="--tags $ARG"; DESC="tag '$ARG' do site.yml" ;;
esac

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

echo "==> [6/6] Aplicando: $DESC ..."
docker exec "$CONTAINER" bash -lc "cd /root/trabalho-iac && ansible-playbook $PLAYBOOK $EXTRA"

echo ""
echo "============================================================"
echo " PRONTO! ABRA NO SEU NAVEGADOR (Windows):"
echo ""
echo "   http://localhost:8080                -> página do servidor"
echo "   http://localhost:8080/produtos.html  -> front (catálogo de produtos)"
echo "   http://localhost:8080/api/produtos   -> API (JSON)"
echo "   http://localhost:9100/metrics        -> métricas (Node Exporter)"
echo ""
echo " Para ver as evidências no terminal, use:"
echo ""
echo "   docker exec $CONTAINER ufw status verbose"
echo "   docker exec $CONTAINER fail2ban-client status sshd"
echo "   docker exec $CONTAINER ls -lh /var/backups/trabalho-iac/"
echo "   docker exec $CONTAINER sqlite3 /opt/app/dados.db 'SELECT * FROM produtos;'"
echo ""
echo " Rodar só uma etapa:   ./testar-local.sh 03   (01..06)"
echo " Shell no servidor:    docker exec -it $CONTAINER bash"
echo " Derrubar tudo:        docker compose -f docker/docker-compose.yml down -v"
echo "============================================================"
