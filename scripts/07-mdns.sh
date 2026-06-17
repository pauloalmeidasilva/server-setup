#!/bin/bash
# =============================================================================
# 06-mdns.sh — Configura Avahi para resolução mDNS local (empresa.local)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

LOCAL_DOMAIN="${LOCAL_DOMAIN:-empresa.local}"

# Extrai o "hostname" da parte esquerda do domínio (empresa.local → empresa)
MDNS_HOSTNAME="${LOCAL_DOMAIN%%.*}"

log_step "Instalando Avahi (mDNS)"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    avahi-daemon avahi-utils libnss-mdns

# ─── Configura avahi-daemon ───────────────────────────────────────────────
log_step "Configurando Avahi para ${LOCAL_DOMAIN}"

backup_file /etc/avahi/avahi-daemon.conf

cat > /etc/avahi/avahi-daemon.conf <<EOF
# ============================================================
# Avahi mDNS — server-setup
# Servidor acessível como: ${MDNS_HOSTNAME}.local
# ============================================================

[server]
; Define o hostname que o Avahi publica (sem .local)
host-name=${MDNS_HOSTNAME}
; Sufixo de domínio mDNS (sempre .local para compatibilidade RFC 6762)
domain-name=local
use-ipv4=yes
use-ipv6=no
check-response-ttl=no
use-iff-running=no

[wide-area]
enable-wide-area=yes

[publish]
disable-publishing=no
add-service-cookie=yes
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes

[reflector]
enable-reflector=no

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=768
rlimit-stack=4194304
rlimit-nproc=3
EOF

# ─── Configura NSSwitch para resolver .local via mDNS ────────────────────
if ! grep -q 'mdns4_minimal' /etc/nsswitch.conf; then
    sed -i 's/^hosts:.*/hosts:          files mdns4_minimal [NOTFOUND=return] dns/' \
        /etc/nsswitch.conf
    log_ok "NSSwitch: configurado para resolver .local via mDNS."
fi

# ─── Ativa e inicia Avahi ─────────────────────────────────────────────────
systemctl enable avahi-daemon
systemctl restart avahi-daemon

wait_service avahi-daemon
log_ok "Avahi iniciado."

# ─── Publica serviços web no mDNS ─────────────────────────────────────────
mkdir -p /etc/avahi/services

cat > /etc/avahi/services/http.service <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h — Servidor Web</name>
  <service>
    <type>_http._tcp</type>
    <port>80</port>
  </service>
  <service>
    <type>_https._tcp</type>
    <port>443</port>
  </service>
</service-group>
EOF

cat > /etc/avahi/services/ssh.service <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h — SSH</name>
  <service>
    <type>_ssh._tcp</type>
    <port>${SSH_PORT:-22}</port>
  </service>
</service-group>
EOF

systemctl restart avahi-daemon

log_ok ""
log_ok "mDNS configurado."
log_ok "  O servidor estará acessível como:"
log_ok "    ${MDNS_HOSTNAME}.local"
log_ok "    (em clientes Linux/macOS com suporte mDNS nativo)"
log_warn ""
log_warn "O nome '${LOCAL_DOMAIN}' via mDNS usa '${MDNS_HOSTNAME}.local'."
log_warn "Para usar '${LOCAL_DOMAIN}' exatamente, configure um CNAME/A"
log_warn "no seu roteador/DNS local apontando para o IP deste servidor."
