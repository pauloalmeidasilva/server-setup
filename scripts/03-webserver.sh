#!/bin/bash
# =============================================================================
# 03-webserver.sh — Instala e configura Nginx, PHP 8.3-FPM e MariaDB
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

PHP_VERSION="${PHP_VERSION:-8.3}"

# ══════════════════════════════════════════════════════════════════════════
# NGINX
# ══════════════════════════════════════════════════════════════════════════
log_step "Instalando Nginx"

apt-get install -y nginx
systemctl enable nginx

# Aplica configuração principal otimizada
backup_file /etc/nginx/nginx.conf
cp "${ROOT_DIR}/templates/nginx/nginx.conf" /etc/nginx/nginx.conf

# Garante que os diretórios de sites existem
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# Remove virtual host padrão
rm -f /etc/nginx/sites-enabled/default

# Snippets de segurança e SSL
mkdir -p /etc/nginx/snippets
cp "${ROOT_DIR}/templates/nginx/ssl-params.conf"       /etc/nginx/snippets/ssl-params.conf
cp "${ROOT_DIR}/templates/nginx/security-headers.conf" /etc/nginx/snippets/security-headers.conf

# Cache FastCGI
mkdir -p /var/cache/nginx

nginx -t && systemctl reload nginx
log_ok "Nginx instalado e configurado."

# ══════════════════════════════════════════════════════════════════════════
# PHP-FPM
# ══════════════════════════════════════════════════════════════════════════
log_step "Instalando PHP ${PHP_VERSION}-FPM"

# Adiciona repositório do Ondřej Surý (versões PHP atualizadas)
add-apt-repository -y ppa:ondrej/php
apt-get update -q

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "php${PHP_VERSION}-fpm" \
    "php${PHP_VERSION}-cli" \
    "php${PHP_VERSION}-mysql" \
    "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-gd" \
    "php${PHP_VERSION}-mbstring" \
    "php${PHP_VERSION}-xml" \
    "php${PHP_VERSION}-zip" \
    "php${PHP_VERSION}-intl" \
    "php${PHP_VERSION}-bcmath" \
    "php${PHP_VERSION}-opcache" \
    "php${PHP_VERSION}-soap" \
    "php${PHP_VERSION}-imagick" \
    "php${PHP_VERSION}-redis"

systemctl enable "php${PHP_VERSION}-fpm"

# ─── PHP.ini — configuração segura e otimizada ────────────────────────────
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
backup_file "$PHP_INI"

php_set() { sed -i "s|^;*\s*${1}\s*=.*|${1} = ${2}|" "$PHP_INI"; }

php_set expose_php          Off
php_set upload_max_filesize 64M
php_set post_max_size       64M
php_set max_execution_time  120
php_set max_input_time      120
php_set memory_limit        256M
php_set display_errors      Off
php_set log_errors          On
php_set error_log           "/var/log/php/php${PHP_VERSION}-error.log"
php_set date.timezone       "${TIMEZONE:-America/Sao_Paulo}"
php_set session.cookie_httponly 1
php_set session.cookie_secure   1
php_set session.use_strict_mode 1

# ─── OPcache ──────────────────────────────────────────────────────────────
cat > "/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini" <<EOF
[opcache]
opcache.enable                 = 1
opcache.memory_consumption     = 128
opcache.interned_strings_buffer= 8
opcache.max_accelerated_files  = 10000
opcache.revalidate_freq        = 2
opcache.fast_shutdown          = 1
opcache.enable_cli             = 0
EOF

# ─── Pool www padrão (otimizado) ──────────────────────────────────────────
backup_file "/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

cat > "/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf" <<EOF
[www]
user  = www-data
group = www-data

listen       = /run/php/php${PHP_VERSION}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode  = 0660

pm                   = dynamic
pm.max_children      = 20
pm.start_servers     = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests      = 1000

; Limpa variáveis de ambiente herdadas do sistema (segurança)
clear_env = yes

chdir = /

php_admin_value[error_log]  = /var/log/php/php${PHP_VERSION}-fpm-www.log
php_admin_flag[log_errors]  = on
EOF

mkdir -p /var/log/php
systemctl restart "php${PHP_VERSION}-fpm"
log_ok "PHP ${PHP_VERSION}-FPM instalado e configurado."

# ══════════════════════════════════════════════════════════════════════════
# MARIADB
# ══════════════════════════════════════════════════════════════════════════
log_step "Instalando MariaDB"

DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

wait_service mariadb

# ─── Gera ou usa senha root ───────────────────────────────────────────────
DB_ROOT_PASS="${MARIADB_ROOT_PASSWORD:-}"
if [[ -z "$DB_ROOT_PASS" ]]; then
    DB_ROOT_PASS="$(random_password 24)"
    log_warn "Senha root gerada automaticamente."
fi

# ─── Secure Installation equivalente ─────────────────────────────────────
mysql --user=root <<SQL
-- Define senha root via plugin nativo
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';

-- Remove usuários anônimos
DELETE FROM mysql.user WHERE User = '';

-- Impede acesso root remoto
DELETE FROM mysql.user
    WHERE User = 'root'
    AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove banco de teste
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db = 'test' OR Db = 'test\\_%';

FLUSH PRIVILEGES;
SQL

save_credential "MARIADB_ROOT_PASSWORD" "$DB_ROOT_PASS"
log_ok "MariaDB: senha root salva em /root/.server-credentials"

# ─── Configuração de segurança e performance ──────────────────────────────
MARIADB_CONF="/etc/mysql/mariadb.conf.d/99-server-setup.cnf"
cat > "$MARIADB_CONF" <<EOF
# Configurações adicionais — server-setup
[mysqld]

# Segurança
skip-symbolic-links
local-infile         = 0
bind-address         = 127.0.0.1

# Performance básica (ajuste conforme RAM disponível)
innodb_buffer_pool_size   = 128M
innodb_log_file_size      = 32M
innodb_flush_method       = O_DIRECT
query_cache_size          = 0
query_cache_type          = 0
max_connections           = 100
EOF

systemctl restart mariadb
log_ok "MariaDB configurado (bind: 127.0.0.1, sem acesso remoto root)."

log_ok ""
log_ok "Stack LEMP (Nginx + PHP ${PHP_VERSION} + MariaDB) instalada com sucesso."
