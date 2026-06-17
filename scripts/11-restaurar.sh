#!/bin/bash
# =============================================================================
# 11-restaurar.sh — Restaura um backup do servidor (interativo)
# Uso: sudo bash scripts/11-restaurar.sh
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

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║     🔄  Restauração de Backup         ║"
echo -e "╚══════════════════════════════════════╝${NC}"
echo ""

# ─── Lista backups disponíveis ────────────────────────────────────────────
mapfile -t BACKUPS < <(find "${BACKUP_DIR}" -maxdepth 1 -mindepth 1 -type d | sort -r)

if [[ ${#BACKUPS[@]} -eq 0 ]]; then
    log_error "Nenhum backup encontrado em: ${BACKUP_DIR}"
    exit 1
fi

echo -e "  ${BOLD}Backups disponíveis:${NC}"
echo ""
for i in "${!BACKUPS[@]}"; do
    BNAME="$(basename "${BACKUPS[$i]}")"
    BSIZE="$(du -sh "${BACKUPS[$i]}" 2>/dev/null | cut -f1)"
    echo -e "  ${CYAN}$(( i + 1 ))${NC}) ${BNAME}  (${BSIZE})"
done

echo ""
read -rp "  Selecione o número do backup para restaurar: " CHOICE

# Valida entrada
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || \
   (( CHOICE < 1 || CHOICE > ${#BACKUPS[@]} )); then
    log_error "Seleção inválida: ${CHOICE}"
    exit 1
fi

BACKUP_PATH="${BACKUPS[$((CHOICE - 1))]}"
BACKUP_NAME="$(basename "$BACKUP_PATH")"

echo ""
log_warn "Backup selecionado: ${BACKUP_NAME}"
log_warn "ATENÇÃO: esta operação sobrescreverá os dados atuais!"
echo ""
read -rp "  Tem certeza? Digite 'sim' para confirmar: " CONFIRM

if [[ "${CONFIRM,,}" != "sim" ]]; then
    log_info "Operação cancelada pelo usuário."
    exit 0
fi

# ─── Restaura bancos de dados ─────────────────────────────────────────────
if [[ -d "${BACKUP_PATH}/databases" ]]; then
    log_step "Restaurando bancos de dados MariaDB"

    DB_ROOT_PASS="$(read_credential 'MARIADB_ROOT_PASSWORD')"
    if [[ -z "$DB_ROOT_PASS" ]]; then
        log_error "Senha root MariaDB não encontrada. Pulando restauração de bancos."
    else
        for DUMP_FILE in "${BACKUP_PATH}/databases/"*.sql.gz; do
            [[ -f "$DUMP_FILE" ]] || continue
            DB_NAME="$(basename "$DUMP_FILE" .sql.gz)"
            log_info "  Restaurando banco: ${DB_NAME}"

            mysql -u root -p"${DB_ROOT_PASS}" \
                -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;" 2>/dev/null

            gunzip -c "$DUMP_FILE" \
                | mysql -u root -p"${DB_ROOT_PASS}" "${DB_NAME}"

            log_ok "  ${DB_NAME} restaurado."
        done
    fi
fi

# ─── Restaura arquivos de sites ───────────────────────────────────────────
if [[ -f "${BACKUP_PATH}/sites.tar.gz" ]]; then
    log_step "Restaurando arquivos de sites"
    tar -xzf "${BACKUP_PATH}/sites.tar.gz" \
        -C "$(dirname "${WEB_ROOT}")"
    chown -R www-data:www-data "${WEB_ROOT}"
    log_ok "Arquivos de sites restaurados em: ${WEB_ROOT}"
fi

# ─── Restaura configurações (opcional) ───────────────────────────────────
if [[ -f "${BACKUP_PATH}/configs.tar.gz" ]]; then
    echo ""
    read -rp "  Restaurar também as configurações do servidor (Nginx/PHP)? [s/N]: " REST_CONF
    if [[ "${REST_CONF,,}" == "s" ]]; then
        log_step "Restaurando configurações"
        tar -xzf "${BACKUP_PATH}/configs.tar.gz" -C /
        nginx -t && systemctl reload nginx
        log_ok "Configurações restauradas."
    fi
fi

# ─── Recarrega serviços ───────────────────────────────────────────────────
nginx -t && nginx -s reload 2>/dev/null || true

log_ok ""
log_ok "Restauração concluída a partir de: ${BACKUP_NAME}"
