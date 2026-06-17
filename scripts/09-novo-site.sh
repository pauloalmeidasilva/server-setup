#!/bin/bash
# =============================================================================
# 09-novo-site.sh — Provisiona um novo virtual host Nginx
# Uso: sudo bash scripts/09-novo-site.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

PHP_VERSION="${PHP_VERSION:-8.3}"
WEB_ROOT="${WEB_ROOT:-/srv/sites}"
LOCAL_DOMAIN="${LOCAL_DOMAIN:-empresa.local}"
SSL_DIR="/etc/ssl/local"

# ══════════════════════════════════════════════════════════════════════════
# COLETA DE INFORMAÇÕES
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║     🌐  Criação de Novo Site          ║"
echo -e "╚══════════════════════════════════════╝${NC}"
echo ""

read -rp "  Nome do site (slug, ex: meusite): " SITE_NAME
SITE_NAME="${SITE_NAME,,}"                     # lowercase
SITE_NAME="${SITE_NAME//[^a-z0-9-]/}"         # remove caracteres inválidos

if [[ -z "$SITE_NAME" ]]; then
    log_error "Nome do site inválido ou vazio."; exit 1
fi

SITE_DOMAIN_DEFAULT="${SITE_NAME}.${LOCAL_DOMAIN}"
read -rp "  Domínio [${SITE_DOMAIN_DEFAULT}]: " SITE_DOMAIN_INPUT
SITE_DOMAIN="${SITE_DOMAIN_INPUT:-$SITE_DOMAIN_DEFAULT}"

SITE_ROOT="${WEB_ROOT}/${SITE_NAME}"
SITE_PUBLIC="${SITE_ROOT}/public"
SITE_LOGS="${SITE_ROOT}/logs"

read -rp "  Habilitar PHP-FPM neste site? [S/n]: " USE_PHP_INPUT
USE_PHP="${USE_PHP_INPUT:-S}"

read -rp "  Criar banco de dados MariaDB? [S/n]: " USE_DB_INPUT
USE_DB="${USE_DB_INPUT:-S}"

echo ""
echo -e "  ${BOLD}Resumo:${NC}"
echo -e "  Site:      ${SITE_NAME}"
echo -e "  Domínio:   ${SITE_DOMAIN}"
echo -e "  Raiz:      ${SITE_ROOT}"
echo -e "  PHP-FPM:   $([[ "${USE_PHP,,}" != "n" ]] && echo "Sim" || echo "Não")"
echo -e "  MariaDB:   $([[ "${USE_DB,,}" != "n" ]] && echo "Sim" || echo "Não")"
echo ""
read -rp "  Confirmar criação? [S/n]: " CONFIRM
[[ "${CONFIRM:-S}" == "n" ]] && { log_info "Operação cancelada."; exit 0; }

# ══════════════════════════════════════════════════════════════════════════
# DIRETÓRIOS E PÁGINA INICIAL
# ══════════════════════════════════════════════════════════════════════════
log_step "Criando estrutura de diretórios"

mkdir -p "${SITE_PUBLIC}" "${SITE_LOGS}"

# Página de boas-vindas estilizada
cat > "${SITE_PUBLIC}/index.html" <<HTML
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${SITE_DOMAIN} — Online</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: system-ui, -apple-system, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            color: #fff;
        }
        .card {
            text-align: center;
            padding: 3.5rem 4rem;
            background: rgba(255,255,255,.06);
            backdrop-filter: blur(20px);
            border: 1px solid rgba(255,255,255,.12);
            border-radius: 1.25rem;
            box-shadow: 0 25px 60px rgba(0,0,0,.5);
        }
        .icon { font-size: 4rem; margin-bottom: 1rem; }
        h1 { font-size: 1.8rem; font-weight: 700; margin-bottom: .5rem; }
        p  { color: #94a3b8; margin-top: .5rem; font-size: .95rem; }
        code {
            display: inline-block; margin-top: 1rem;
            padding: .35rem .75rem;
            background: rgba(255,255,255,.08);
            border-radius: .4rem;
            font-family: monospace;
            font-size: .9rem;
            color: #7dd3fc;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">🚀</div>
        <h1>${SITE_DOMAIN}</h1>
        <p>Site criado com sucesso e funcionando!</p>
        <p>Coloque seus arquivos em:</p>
        <code>${SITE_PUBLIC}</code>
    </div>
</body>
</html>
HTML

chown -R www-data:www-data "${SITE_ROOT}"
chmod -R 755 "${SITE_ROOT}"
log_ok "Diretório criado: ${SITE_ROOT}"

# ══════════════════════════════════════════════════════════════════════════
# CERTIFICADO SSL
# ══════════════════════════════════════════════════════════════════════════
log_step "Gerando certificado SSL para ${SITE_DOMAIN}"

SITE_KEY="${SSL_DIR}/${SITE_DOMAIN}.key"
SITE_CRT="${SSL_DIR}/${SITE_DOMAIN}.crt"

SSL_CNF="$(mktemp /tmp/ssl-site-XXXXXX.cnf)"
trap 'rm -f "$SSL_CNF"' EXIT

cat > "$SSL_CNF" <<EOF
[req]
default_bits       = 2048
default_md         = sha256
distinguished_name = req_distinguished_name
x509_extensions    = v3_req
prompt             = no

[req_distinguished_name]
CN = ${SITE_DOMAIN}

[v3_req]
keyUsage         = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[alt_names]
DNS.1 = ${SITE_DOMAIN}
DNS.2 = www.${SITE_DOMAIN}
EOF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$SITE_KEY" \
    -out    "$SITE_CRT" \
    -config "$SSL_CNF" 2>/dev/null

chmod 600 "$SITE_KEY"
chmod 644 "$SITE_CRT"
log_ok "SSL gerado: ${SITE_CRT}"

# ══════════════════════════════════════════════════════════════════════════
# PHP-FPM POOL
# ══════════════════════════════════════════════════════════════════════════
FPM_SOCKET=""
if [[ "${USE_PHP,,}" != "n" ]]; then
    log_step "Criando pool PHP-FPM para ${SITE_NAME}"

    FPM_SOCKET="/run/php/php${PHP_VERSION}-fpm-${SITE_NAME}.sock"

    cat > "/etc/php/${PHP_VERSION}/fpm/pool.d/${SITE_NAME}.conf" <<EOF
[${SITE_NAME}]
user  = www-data
group = www-data

listen       = ${FPM_SOCKET}
listen.owner = www-data
listen.group = www-data
listen.mode  = 0660

pm                   = dynamic
pm.max_children      = 10
pm.start_servers     = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 4
pm.max_requests      = 500

clear_env = yes
chdir     = /

php_admin_value[open_basedir]      = ${SITE_ROOT}:/tmp
php_admin_value[error_log]         = ${SITE_LOGS}/php-error.log
php_admin_flag[log_errors]         = on
php_admin_value[session.save_path] = /tmp
EOF

    systemctl restart "php${PHP_VERSION}-fpm"
    log_ok "Pool PHP-FPM criado: ${FPM_SOCKET}"
fi

# ══════════════════════════════════════════════════════════════════════════
# VIRTUAL HOST NGINX
# ══════════════════════════════════════════════════════════════════════════
log_step "Criando virtual host Nginx"

NGINX_CONF="/etc/nginx/sites-available/${SITE_NAME}.conf"

# Bloco PHP condicional
if [[ -n "$FPM_SOCKET" ]]; then
    PHP_LOCATION="
    location ~ \.php\$ {
        fastcgi_pass unix:${FPM_SOCKET};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 120;
    }"
    INDEX_FILES="index.php index.html index.htm"
else
    PHP_LOCATION=""
    INDEX_FILES="index.html index.htm"
fi

cat > "$NGINX_CONF" <<NGINX
# Virtual Host: ${SITE_DOMAIN}
# Gerado por: server-setup — $(date '+%d/%m/%Y %H:%M')

# ── HTTP → HTTPS redirect ──────────────────────────────────────────
server {
    listen      80;
    server_name ${SITE_DOMAIN} www.${SITE_DOMAIN};

    # ACME challenge (para eventual Certbot no futuro)
    location /.well-known/acme-challenge/ {
        root ${SITE_PUBLIC};
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# ── HTTPS ──────────────────────────────────────────────────────────
server {
    listen      443 ssl http2;
    server_name ${SITE_DOMAIN} www.${SITE_DOMAIN};

    root  ${SITE_PUBLIC};
    index ${INDEX_FILES};

    # SSL
    ssl_certificate     ${SITE_CRT};
    ssl_certificate_key ${SITE_KEY};
    include snippets/ssl-params.conf;

    # Logs por site
    access_log ${SITE_LOGS}/access.log;
    error_log  ${SITE_LOGS}/error.log warn;

    # Cabeçalhos de segurança
    include snippets/security-headers.conf;

    # Bloqueia acesso a arquivos ocultos
    location ~ /\. { deny all; }

    # Cache de assets estáticos
    location ~* \.(css|js|ico|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot|map)\$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
        access_log off;
    }

    # Rota principal
    location / {
        try_files \$uri \$uri/ =404;
    }
${PHP_LOCATION}
}
NGINX

# Ativa o site com symlink
ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/${SITE_NAME}.conf"

nginx -t && nginx -s reload
log_ok "Virtual host ativado: https://${SITE_DOMAIN}"

# ══════════════════════════════════════════════════════════════════════════
# MARIADB
# ══════════════════════════════════════════════════════════════════════════
DB_NAME=""
DB_USER=""
if [[ "${USE_DB,,}" != "n" ]]; then
    log_step "Criando banco de dados MariaDB"

    DB_NAME="${SITE_NAME//-/_}"
    DB_USER="$DB_NAME"
    DB_PASS="$(random_password 20)"
    DB_ROOT_PASS="$(read_credential 'MARIADB_ROOT_PASSWORD')"

    if [[ -z "$DB_ROOT_PASS" ]]; then
        log_error "Senha root MariaDB não encontrada em /root/.server-credentials"
        log_error "Execute scripts/03-webserver.sh antes de criar um site com banco."
    else
        mysql -u root -p"${DB_ROOT_PASS}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

        save_credential "DB_${SITE_NAME^^}_NAME" "$DB_NAME"
        save_credential "DB_${SITE_NAME^^}_USER" "$DB_USER"
        save_credential "DB_${SITE_NAME^^}_PASS" "$DB_PASS"
        log_ok "Banco criado: ${DB_NAME}"
        log_ok "Usuário: ${DB_USER} | Credenciais: /root/.server-credentials"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════
# RESUMO
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}  ✓ Site '${SITE_NAME}' criado com sucesso!${NC}"
echo ""
echo -e "  🌐 URL:        https://${SITE_DOMAIN}"
echo -e "  📂 Arquivos:   ${SITE_PUBLIC}"
echo -e "  📋 Logs:       ${SITE_LOGS}"
[[ -n "$DB_NAME" ]] && echo -e "  🗄️  Banco:      ${DB_NAME} (usuário: ${DB_USER})"
echo ""
echo -e "  ${YELLOW}⚠  Adicione '${SITE_DOMAIN}' ao DNS local apontando para o IP do servidor${NC}"
