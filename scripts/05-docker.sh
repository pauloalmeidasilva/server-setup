#!/bin/bash
# =============================================================================
# 05-docker.sh — Instala Docker CE e Docker Compose Plugin
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

log_step "Instalando Docker CE"

# ─── Pré-requisitos ────────────────────────────────────────────────────────
apt-get install -y ca-certificates gnupg

# ─── Chave GPG oficial Docker ─────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# ─── Repositório estável ──────────────────────────────────────────────────
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker

wait_service docker
log_ok "Docker instalado e em execução."

# ─── Daemon — configurações de segurança e logging ────────────────────────
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "live-restore": true,
    "userland-proxy": false,
    "no-new-privileges": true
}
EOF

systemctl restart docker

# ─── Adiciona o usuário administrador ao grupo docker ─────────────────────
ADMIN_USER="${SUDO_USER:-}"
if [[ -n "$ADMIN_USER" ]] && id "$ADMIN_USER" &>/dev/null; then
    usermod -aG docker "$ADMIN_USER"
    log_ok "Usuário '${ADMIN_USER}' adicionado ao grupo docker."
    log_warn "Faça logout/login para efetivar a permissão de usar Docker sem sudo."
fi

DOCKER_VER="$(docker --version | awk '{print $3}' | tr -d ',')"
COMPOSE_VER="$(docker compose version --short)"

log_ok ""
log_ok "Docker ${DOCKER_VER} instalado."
log_ok "Docker Compose ${COMPOSE_VER} instalado."
log_ok "Uso: docker run | docker compose up -d"
