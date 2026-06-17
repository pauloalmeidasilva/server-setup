#!/bin/bash
# =============================================================================
# 10-backup.sh — Backup automático de bancos, sites e configurações
# Uso manual:  sudo bash scripts/10-backup.sh
# Automático:  configurado via cron ao final deste script (03:00 diariamente)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"
WEB_ROOT="${WEB_ROOT:-/srv/sites}"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
KEEP_DAYS=7   # Mantém backups dos últimos N dias

log_step "Iniciando backup — ${TIMESTAMP}"
mkdir -p "${BACKUP_PATH}"

# ──────────────────────────────────────────────────────────────────────────
# DUMP DE BANCOS MARIADB
# ──────────────────────────────────────────────────────────────────────────
DB_ROOT_PASS="$(read_credential 'MARIADB_ROOT_PASSWORD')"

if [[ -n "$DB_ROOT_PASS" ]]; then
    log_info "Fazendo dump de todos os bancos MariaDB..."
    mkdir -p "${BACKUP_PATH}/databases"

    # Lista bancos excluindo os internos do sistema
    DATABASES="$(mysql -u root -p"${DB_ROOT_PASS}" \
        -e "SHOW DATABASES;" 2>/dev/null \
        | grep -Ev "^(Database|information_schema|performance_schema|sys|mysql)$" || true)"

    if [[ -n "$DATABASES" ]]; then
        while IFS= read -r DB; do
            [[ -z "$DB" ]] && continue
            mysqldump -u root -p"${DB_ROOT_PASS}" \
                --single-transaction \
                --routines \
                --triggers \
                --events \
                "$DB" 2>/dev/null \
                | gzip > "${BACKUP_PATH}/databases/${DB}.sql.gz"
            log_ok "  Dump: ${DB}"
        done <<< "$DATABASES"
    else
        log_warn "Nenhum banco de dados de usuário encontrado."
    fi
else
    log_warn "Senha MariaDB não encontrada. Pulando dump de bancos."
fi

# ──────────────────────────────────────────────────────────────────────────
# ARQUIVOS DOS SITES
# ──────────────────────────────────────────────────────────────────────────
if [[ -d "$WEB_ROOT" ]]; then
    log_info "Compactando arquivos de sites..."
    tar -czf "${BACKUP_PATH}/sites.tar.gz" \
        -C "$(dirname "$WEB_ROOT")" \
        "$(basename "$WEB_ROOT")" \
        2>/dev/null || log_warn "Alguns arquivos podem ter sido pulados."
    log_ok "Sites compactados: ${BACKUP_PATH}/sites.tar.gz"
fi

# ──────────────────────────────────────────────────────────────────────────
# CONFIGURAÇÕES DO SERVIDOR
# ──────────────────────────────────────────────────────────────────────────
log_info "Salvando configurações do servidor..."
tar -czf "${BACKUP_PATH}/configs.tar.gz" \
    /etc/nginx \
    /etc/php \
    /etc/mysql \
    /etc/ssh/sshd_config \
    /etc/fail2ban/jail.local \
    2>/dev/null || true
log_ok "Configurações salvas: ${BACKUP_PATH}/configs.tar.gz"

# ──────────────────────────────────────────────────────────────────────────
# LIMPEZA DE BACKUPS ANTIGOS
# ──────────────────────────────────────────────────────────────────────────
log_info "Removendo backups com mais de ${KEEP_DAYS} dias..."
find "${BACKUP_DIR}" -maxdepth 1 -mindepth 1 -type d -mtime "+${KEEP_DAYS}" \
    | while read -r OLD_BACKUP; do
        rm -rf "${OLD_BACKUP}"
        log_ok "  Removido: $(basename "$OLD_BACKUP")"
    done

# ──────────────────────────────────────────────────────────────────────────
# RELATÓRIO
# ──────────────────────────────────────────────────────────────────────────
TOTAL_SIZE="$(du -sh "${BACKUP_PATH}" 2>/dev/null | cut -f1)"
TOTAL_COUNT="$(find "${BACKUP_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l)"

log_ok ""
log_ok "Backup concluído:"
log_ok "  Destino:  ${BACKUP_PATH}"
log_ok "  Tamanho:  ${TOTAL_SIZE}"
log_ok "  Total de backups mantidos: ${TOTAL_COUNT}"

# ──────────────────────────────────────────────────────────────────────────
# CRON AUTOMÁTICO (configura na primeira execução)
# ──────────────────────────────────────────────────────────────────────────
CRON_MARK="server-setup-backup"
if ! crontab -l 2>/dev/null | grep -q "$CRON_MARK"; then
    CRON_LINE="0 3 * * * bash ${SCRIPT_DIR}/10-backup.sh >> /var/log/server-backup.log 2>&1  # ${CRON_MARK}"
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    log_ok "Backup agendado: diariamente às 03:00."
    log_ok "  Log: /var/log/server-backup.log"
fi
