#!/bin/bash
# =============================================================================
# 04-nodejs.sh — Instala Node.js (via NodeSource) e PM2
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

NODEJS_VERSION="${NODEJS_VERSION:-22}"

log_step "Instalando Node.js ${NODEJS_VERSION}.x (via NodeSource)"

# Adiciona repositório oficial NodeSource
curl -fsSL "https://deb.nodesource.com/setup_${NODEJS_VERSION}.x" | bash -

DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

NODE_VER="$(node --version)"
NPM_VER="$(npm --version)"
log_ok "Node.js ${NODE_VER} instalado."
log_ok "npm ${NPM_VER} instalado."

# ─── PM2 ─────────────────────────────────────────────────────────────────
log_step "Instalando PM2 (gerenciador de processos Node.js)"

npm install -g pm2

# Configura PM2 para iniciar com o sistema (via systemd)
PM2_STARTUP="$(pm2 startup systemd -u root --hp /root 2>&1 | grep 'sudo' || true)"
if [[ -n "$PM2_STARTUP" ]]; then
    eval "$PM2_STARTUP"
fi

pm2 save --force

PM2_VER="$(pm2 --version)"
log_ok "PM2 ${PM2_VER} instalado e configurado para iniciar com o sistema."

log_ok ""
log_ok "Node.js e PM2 instalados."
log_ok "  Iniciar app:    pm2 start app.js --name meu-app"
log_ok "  Ver processos:  pm2 list"
log_ok "  Logs:           pm2 logs"
