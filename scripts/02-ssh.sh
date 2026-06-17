#!/bin/bash
# =============================================================================
# 02-ssh.sh — Endurecimento do acesso SSH (key-only, sem root, com banner)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

SSH_CONFIG="/etc/ssh/sshd_config"

# Detecta o usuário administrador (quem invocou o sudo)
ADMIN_USER="${SUDO_USER:-}"
if [[ -z "$ADMIN_USER" ]] || [[ "$ADMIN_USER" == "root" ]]; then
    # Tenta encontrar o primeiro usuário humano (UID >= 1000)
    ADMIN_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}')"
fi

HOME_DIR="$(getent passwd "${ADMIN_USER:-root}" | cut -d: -f6)"

log_step "Instalando chave pública SSH"

if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    log_info "Configurando chave para o usuário: ${ADMIN_USER}"

    mkdir -p "${HOME_DIR}/.ssh"
    chmod 700 "${HOME_DIR}/.ssh"

    # Adiciona chave apenas se ainda não existir no arquivo
    if ! grep -qF "${SSH_PUBLIC_KEY}" "${HOME_DIR}/.ssh/authorized_keys" 2>/dev/null; then
        echo "${SSH_PUBLIC_KEY}" >> "${HOME_DIR}/.ssh/authorized_keys"
    fi

    chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
    chown -R "${ADMIN_USER}:${ADMIN_USER}" "${HOME_DIR}/.ssh"

    log_ok "Chave pública instalada para: ${ADMIN_USER}"
    PASSWORD_AUTH="no"
else
    log_warn "SSH_PUBLIC_KEY não definida no .env"
    log_warn "Autenticação por senha mantida como fallback temporário."
    log_warn "Adicione a chave pública ao .env e re-execute: sudo bash scripts/02-ssh.sh"
    PASSWORD_AUTH="yes"
fi

# ─── Configuração segura do sshd ───────────────────────────────────────────
log_step "Aplicando configuração segura do SSH"

backup_file "$SSH_CONFIG"

cat > "$SSH_CONFIG" <<EOF
# ============================================================
# SSH Server Configuration — server-setup
# Gerado em: $(date '+%d/%m/%Y %H:%M:%S')
# ============================================================

# Porta e protocolo
Port ${SSH_PORT:-22}
Protocol 2
AddressFamily inet

# Autenticação — root e senha
PermitRootLogin no
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30

# Chave pública
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Senha
PasswordAuthentication ${PASSWORD_AUTH}
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no

# PAM
UsePAM yes

# Keep-alive (evita desconexão por inatividade)
ClientAliveInterval 120
ClientAliveCountMax 3

# Restrições de recursos
X11Forwarding no
PrintMotd no
AllowAgentForwarding no
AllowTcpForwarding no

# Variáveis de ambiente permitidas
AcceptEnv LANG LC_*

# Banner de aviso legal
Banner /etc/ssh/banner.txt

# SFTP interno (para transferências de arquivo com clientes como FileZilla)
Subsystem sftp /usr/lib/openssh/sftp-server -u 0027
EOF

# ─── Banner de aviso legal ────────────────────────────────────────────────
cat > /etc/ssh/banner.txt <<'BANNER'

╔══════════════════════════════════════════════════════════════╗
║   ACESSO RESTRITO — SOMENTE USUÁRIOS AUTORIZADOS             ║
║   Todas as sessões são monitoradas e registradas.            ║
║   Acesso não autorizado é crime — Lei nº 12.737/2012        ║
╚══════════════════════════════════════════════════════════════╝

BANNER

# ─── Valida e reinicia ────────────────────────────────────────────────────
log_step "Validando e aplicando configuração"

if sshd -t 2>/dev/null; then
    systemctl restart sshd
    log_ok "SSH reiniciado com configuração segura."
else
    log_error "Configuração SSH inválida! Restaurando backup..."
    # Restaura o backup mais recente
    LATEST_BAK="$(ls -t "${SSH_CONFIG}.bak."* 2>/dev/null | head -1)"
    if [[ -n "$LATEST_BAK" ]]; then
        cp "$LATEST_BAK" "$SSH_CONFIG"
        systemctl restart sshd
    fi
    exit 1
fi

# ─── Atualiza UFW se a porta mudou ───────────────────────────────────────
if [[ "${SSH_PORT:-22}" != "22" ]]; then
    ufw delete allow 22/tcp 2>/dev/null || true
    ufw allow "${SSH_PORT}/tcp" comment 'SSH (porta customizada)'
    log_ok "UFW: porta SSH atualizada para ${SSH_PORT}."
fi

log_ok ""
log_ok "SSH configurado."
log_ok "  Porta:               ${SSH_PORT:-22}"
log_ok "  Login root:          DESATIVADO"
log_ok "  Autenticação senha:  ${PASSWORD_AUTH^^}"
log_ok "  Autenticação chave:  ATIVADA"
