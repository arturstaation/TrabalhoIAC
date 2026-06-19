# ===========================================================================
# Imagem Ubuntu 22.04 com systemd habilitado, para testar os playbooks
# localmente (como se fosse um servidor de verdade). Inclui Python3 (exigido
# pelo Ansible) e sudo.
# ===========================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

# Pacotes mínimos: systemd, python3 (para o Ansible) e sudo
RUN apt-get update && apt-get install -y \
        systemd systemd-sysv \
        python3 python3-apt \
        sudo iproute2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Remove units do systemd desnecessárias dentro de container
RUN find /etc/systemd/system /lib/systemd/system \
        -path '*.wants/*' \
        \( -name '*getty*' -o -name '*systemd-udevd*' \
        -o -name '*systemd-tmpfiles*' -o -name '*systemd-logind*' \) \
        -exec rm -f {} \; 2>/dev/null || true

VOLUME ["/sys/fs/cgroup"]

# systemd como PID 1
CMD ["/lib/systemd/systemd"]
