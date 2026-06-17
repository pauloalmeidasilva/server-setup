#!/bin/bash
# =============================================================================
# 08-cockpit.sh — Instala Cockpit com SSL e módulos adicionais
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

LOCAL_DOMAIN="${LOCAL_DOMAIN:-empresa.local}"
SSL_DIR="/etc/ssl/local"

log_step "Instalando Cockpit"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cockpit \
    cockpit-packagekit \
    cockpit-storaged \
    cockpit-networkmanager

systemctl enable --now cockpit.socket
log_ok "Cockpit instalado e ativo."

# ─── Aplica certificado SSL gerado em 05-ssl.sh ───────────────────────────
log_step "Configurando SSL no Cockpit"

COCKPIT_CERTS="/etc/cockpit/ws-certs.d"
mkdir -p "$COCKPIT_CERTS"

CERT_KEY="${SSL_DIR}/${LOCAL_DOMAIN}.key"
CERT_CRT="${SSL_DIR}/${LOCAL_DOMAIN}.crt"

if [[ -f "$CERT_KEY" ]] && [[ -f "$CERT_CRT" ]]; then
    # Cockpit espera um .cert (crt+chain) e um .key com o mesmo nome base
    cp "$CERT_CRT" "${COCKPIT_CERTS}/90-server-setup.cert"
    cp "$CERT_KEY" "${COCKPIT_CERTS}/90-server-setup.key"
    chmod 640 "${COCKPIT_CERTS}/90-server-setup.key"
    systemctl restart cockpit.socket
    log_ok "Cockpit configurado com SSL de ${LOCAL_DOMAIN}."
else
    log_warn "Certificado SSL não encontrado em ${SSL_DIR}."
    log_warn "Execute scripts/05-ssl.sh antes deste script para usar HTTPS no Cockpit."
fi

# ─── Configura Cockpit (limita acesso e define URL de origem) ─────────────
mkdir -p /etc/cockpit
cat > /etc/cockpit/cockpit.conf <<EOF
[WebService]
; Permite apenas conexões locais (opcional — remova se quiser acesso externo)
; AllowUnencrypted = false
Origins = https://${LOCAL_DOMAIN}:9090 https://${SERVER_HOSTNAME:-ubuntu-server}.local:9090

[Session]
; Tempo de inatividade antes do logout automático (em segundos)
IdleTimeout = 900
Banner = /etc/cockpit/login-banner.txt
EOF

cat > /etc/cockpit/login-banner.txt <<EOF
Acesso restrito — somente administradores autorizados.
EOF

systemctl restart cockpit.socket
log_ok "Cockpit configurado."

log_ok ""
log_ok "Cockpit disponível em:"
log_ok "  https://${LOCAL_DOMAIN}:9090"
log_ok "  https://${SERVER_HOSTNAME:-ubuntu-server}.local:9090"
log_ok "  Use as credenciais do usuário do sistema para entrar."
