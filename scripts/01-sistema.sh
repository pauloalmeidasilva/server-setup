#!/bin/bash
# =============================================================================
# 01-sistema.sh — Configuração inicial do sistema Ubuntu Server
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

# ─── Atualização do sistema ────────────────────────────────────────────────
log_step "Atualizando pacotes do sistema"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -q
apt-get autoremove -y -q
log_ok "Sistema atualizado."

# ─── Hostname e timezone ───────────────────────────────────────────────────
log_step "Configurando hostname e fuso horário"

hostnamectl set-hostname "${SERVER_HOSTNAME:-ubuntu-server}"
timedatectl set-timezone "${TIMEZONE:-America/Sao_Paulo}"
timedatectl set-ntp true

log_ok "Hostname: $(hostname)"
log_ok "Timezone: $(timedatectl | grep 'Time zone' | awk '{print $3}')"

# ─── Pacotes essenciais ────────────────────────────────────────────────────
log_step "Instalando pacotes essenciais"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget git unzip zip \
    htop iotop nethogs \
    net-tools dnsutils iputils-ping \
    software-properties-common \
    apt-transport-https \
    ca-certificates gnupg lsb-release \
    fail2ban ufw \
    unattended-upgrades apt-listchanges \
    logrotate cron \
    build-essential

log_ok "Pacotes instalados."

# ─── Estrutura de diretórios ───────────────────────────────────────────────
log_step "Criando estrutura de diretórios"

mkdir -p "${WEB_ROOT:-/srv/sites}"
mkdir -p "${BACKUP_DIR:-/srv/backups}"
mkdir -p /opt/scripts
mkdir -p /var/log/php

chmod 755 "${WEB_ROOT:-/srv/sites}"
chmod 700 "${BACKUP_DIR:-/srv/backups}"

log_ok "Diretórios criados: ${WEB_ROOT} | ${BACKUP_DIR}"

# ─── UFW (Firewall) ────────────────────────────────────────────────────────
log_step "Configurando UFW (Firewall)"

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow "${SSH_PORT:-22}/tcp"  comment 'SSH'
ufw allow 80/tcp                 comment 'HTTP'
ufw allow 443/tcp                comment 'HTTPS'

ufw --force enable
log_ok "UFW configurado e ativo."

# ─── Fail2ban ──────────────────────────────────────────────────────────────
log_step "Configurando Fail2ban"

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# Redes internas (RFC 1918) e localhost não serão banidas
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
# Tempo de banimento: 1 hora (em segundos)
bantime  = 3600
# Janela de tempo para contar tentativas: 10 minutos
findtime = 600
# Máximo de tentativas antes do banimento
maxretry = 5
# Backend para leitura de logs
backend  = systemd
# Modo: aggressivo ignora hosts na whitelist
mode     = normal

[sshd]
enabled  = true
port     = ${SSH_PORT:-22}
filter   = sshd
maxretry = 3
bantime  = 86400

[nginx-http-auth]
enabled  = true

[nginx-noscript]
enabled  = true

[nginx-badbots]
enabled  = true

[nginx-noproxy]
enabled  = true
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log_ok "Fail2ban configurado (SSH: banimento 24h após 3 tentativas)."

# ─── Atualizações automáticas de segurança ────────────────────────────────
log_step "Configurando atualizações automáticas de segurança"

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "${ADMIN_EMAIL:-}";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable unattended-upgrades
log_ok "Atualizações automáticas de segurança: ATIVAS."

log_ok ""
log_ok "Configuração do sistema concluída com sucesso."
