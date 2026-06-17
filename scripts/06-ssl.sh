#!/bin/bash
# =============================================================================
# 05-ssl.sh — Gera certificado SSL autoassinado (wildcard) e parâmetros DH
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
CERT_DAYS=3650    # 10 anos
CERT_KEY="${SSL_DIR}/${LOCAL_DOMAIN}.key"
CERT_CRT="${SSL_DIR}/${LOCAL_DOMAIN}.crt"

log_step "Gerando certificado SSL autoassinado para ${LOCAL_DOMAIN}"

mkdir -p "$SSL_DIR"
chmod 700 "$SSL_DIR"

# ─── Arquivo de configuração OpenSSL com SAN (Subject Alternative Names) ──
OPENSSL_CNF="$(mktemp /tmp/ssl-XXXXXX.cnf)"
trap 'rm -f "$OPENSSL_CNF"' EXIT

cat > "$OPENSSL_CNF" <<EOF
[req]
default_bits        = 4096
default_md          = sha256
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
req_extensions      = v3_req
prompt              = no

[req_distinguished_name]
C  = BR
ST = Brasil
L  = Local
O  = ${SERVER_HOSTNAME:-Empresa}
OU = TI
CN = ${LOCAL_DOMAIN}

[v3_req]
keyUsage         = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[v3_ca]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName         = @alt_names

[alt_names]
DNS.1 = ${LOCAL_DOMAIN}
DNS.2 = *.${LOCAL_DOMAIN}
DNS.3 = ${SERVER_HOSTNAME:-ubuntu-server}
DNS.4 = ${SERVER_HOSTNAME:-ubuntu-server}.local
DNS.5 = localhost
IP.1  = 127.0.0.1
EOF

# Gera chave privada e certificado autoassinado
openssl req -x509 -newkey rsa:4096 -sha256 \
    -days "$CERT_DAYS" \
    -nodes \
    -keyout "$CERT_KEY" \
    -out    "$CERT_CRT" \
    -config "$OPENSSL_CNF" 2>/dev/null

chmod 600 "$CERT_KEY"
chmod 644 "$CERT_CRT"

log_ok "Certificado gerado: ${CERT_CRT}"
log_ok "Chave privada:      ${CERT_KEY}"

# ─── Instala como CA confiável no sistema ─────────────────────────────────
cp "$CERT_CRT" "/usr/local/share/ca-certificates/${LOCAL_DOMAIN}.crt"
update-ca-certificates --fresh 2>/dev/null
log_ok "Certificado instalado como CA confiável no sistema."

# ─── Parâmetros Diffie-Hellman ─────────────────────────────────────────────
DHPARAM="${SSL_DIR}/dhparam.pem"
log_step "Gerando parâmetros Diffie-Hellman (2048 bits)"

if [[ -f "$DHPARAM" ]]; then
    log_ok "dhparam já existe — pulando geração."
else
    openssl dhparam -out "$DHPARAM" 2048 2>/dev/null
    log_ok "dhparam gerado: ${DHPARAM}"
fi

chmod 640 "$DHPARAM"

# ─── Atualiza o snippet SSL do Nginx com o caminho correto ────────────────
SNIPPET="/etc/nginx/snippets/ssl-params.conf"
if [[ -f "$SNIPPET" ]]; then
    sed -i "s|ssl_dhparam .*|ssl_dhparam ${DHPARAM};|" "$SNIPPET"
    log_ok "Snippet Nginx ssl-params.conf atualizado."
fi

log_ok ""
log_ok "SSL configurado:"
log_ok "  Cert:    ${CERT_CRT}"
log_ok "  Key:     ${CERT_KEY}"
log_ok "  dhparam: ${DHPARAM}"
log_ok "  Validade: $((CERT_DAYS / 365)) anos"
log_warn "Certificado autoassinado: clientes precisarão aceitar o aviso de segurança"
log_warn "ou importar o certificado manualmente nos dispositivos."
