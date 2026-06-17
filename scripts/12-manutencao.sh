#!/bin/bash
# =============================================================================
# 12-manutencao.sh — Menu interativo de manutenção do servidor
# Uso: sudo bash scripts/12-manutencao.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"
check_root
load_env "$ROOT_DIR"

PHP_VERSION="${PHP_VERSION:-8.3}"
WEB_ROOT="${WEB_ROOT:-/srv/sites}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"

# ─── Painel de status ─────────────────────────────────────────────────────
show_status() {
    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Status dos Serviços${NC}"
    local services=("nginx" "php${PHP_VERSION}-fpm" "mariadb" "docker" "cockpit.socket" "avahi-daemon" "fail2ban")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "    ${GREEN}● ${NC}${svc}"
        else
            echo -e "    ${RED}● ${NC}${svc} (inativo)"
        fi
    done

    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Uso de Disco${NC}"
    df -h / "${WEB_ROOT}" "${BACKUP_DIR}" 2>/dev/null \
        | awk 'NR==1{printf "    %-30s %5s %5s %5s %4s\n",$1,$2,$3,$4,$5} NR>1{printf "    %-30s %5s %5s %5s %4s\n",$6,$2,$3,$4,$5}'

    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Memória${NC}"
    free -h | awk '/Mem/{printf "    Usada: %s / Total: %s (Livre: %s)\n",$3,$2,$4}'

    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Uptime${NC}"
    echo -e "    $(uptime -p)"

    echo ""
    echo -e "  ${BOLD}${CYAN}▸ IPs do Servidor${NC}"
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}(?!/8)' \
        | while read -r ip; do echo "    $ip"; done
}

# ─── Atualização do sistema ───────────────────────────────────────────────
atualizar_sistema() {
    log_step "Atualizando sistema"
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    apt-get autoremove -y
    log_ok "Sistema atualizado com sucesso."
}

# ─── Listar sites ─────────────────────────────────────────────────────────
listar_sites() {
    echo ""
    echo -e "  ${BOLD}Sites configurados:${NC}"
    local found=0
    for conf in /etc/nginx/sites-enabled/*.conf; do
        [[ -f "$conf" ]] || continue
        SITE="$(basename "$conf" .conf)"
        [[ "$SITE" == "default" ]] && continue
        SERVER_NAME="$(grep -m1 'server_name' "$conf" 2>/dev/null | awk '{print $2}' | tr -d ';' || echo '—')"
        echo -e "    ${GREEN}✓${NC} ${SITE}  →  https://${SERVER_NAME}"
        found=1
    done
    [[ $found -eq 0 ]] && echo -e "    ${YELLOW}Nenhum site configurado.${NC}"
    echo ""
}

# ─── Desativar site ───────────────────────────────────────────────────────
desativar_site() {
    echo ""
    echo -e "  ${BOLD}Sites ativos:${NC}"
    mapfile -t SITES < <(find /etc/nginx/sites-enabled -name "*.conf" -type l -o -type f 2>/dev/null | grep -v default)
    
    if [[ ${#SITES[@]} -eq 0 ]]; then
        log_warn "Nenhum site ativo."
        return
    fi
    
    for i in "${!SITES[@]}"; do
        echo -e "    ${CYAN}$(( i + 1 ))${NC}) $(basename "${SITES[$i]}" .conf)"
    done
    echo ""
    read -rp "  Número do site para desativar (0 para cancelar): " CHOICE
    
    [[ "$CHOICE" == "0" ]] && return
    
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#SITES[@]} )); then
        log_error "Opção inválida."
        return
    fi
    
    SITE_CONF="${SITES[$((CHOICE - 1))]}"
    rm -f "$SITE_CONF"
    nginx -t && systemctl reload nginx
    log_ok "Site desativado: $(basename "$SITE_CONF")"
}

# ─── Remover site completo ────────────────────────────────────────────────
remover_site() {
    echo ""
    log_warn "ATENÇÃO: Esta operação remove completamente o site (arquivos + config)!"
    echo ""
    
    mapfile -t SITES < <(find "${WEB_ROOT}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    
    if [[ ${#SITES[@]} -eq 0 ]]; then
        log_warn "Nenhum site encontrado em ${WEB_ROOT}."
        return
    fi
    
    echo -e "  ${BOLD}Sites disponíveis:${NC}"
    for i in "${!SITES[@]}"; do
        SITE_NAME="$(basename "${SITES[$i]}")"
        SITE_SIZE="$(du -sh "${SITES[$i]}" 2>/dev/null | cut -f1)"
        echo -e "    ${CYAN}$(( i + 1 ))${NC}) ${SITE_NAME}  (${SITE_SIZE})"
    done
    echo ""
    read -rp "  Número do site para remover (0 para cancelar): " CHOICE
    
    [[ "$CHOICE" == "0" ]] && return
    
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#SITES[@]} )); then
        log_error "Opção inválida."
        return
    fi
    
    SITE_PATH="${SITES[$((CHOICE - 1))]}"
    SITE_NAME="$(basename "$SITE_PATH")"
    
    echo ""
    read -rp "  Digite '${SITE_NAME}' para confirmar remoção: " CONFIRM
    
    if [[ "$CONFIRM" != "$SITE_NAME" ]]; then
        log_info "Operação cancelada."
        return
    fi
    
    # Remove configuração Nginx
    rm -f "/etc/nginx/sites-enabled/${SITE_NAME}.conf"
    rm -f "/etc/nginx/sites-available/${SITE_NAME}.conf"
    
    # Remove arquivos do site
    rm -rf "$SITE_PATH"
    
    nginx -t && systemctl reload nginx
    log_ok "Site removido completamente: ${SITE_NAME}"
}

# ─── Limpar caches ────────────────────────────────────────────────────────
limpar_caches() {
    log_step "Limpando caches e arquivos temporários"
    
    # Cache do Nginx FastCGI
    rm -rf /var/cache/nginx/*
    log_ok "Cache Nginx limpo"
    
    # Logs antigos (7+ dias)
    find /var/log -type f -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    log_ok "Logs antigos removidos"
    
    # OPcache PHP (reinicia o PHP-FPM)
    systemctl restart "php${PHP_VERSION}-fpm"
    log_ok "OPcache PHP limpo"
    
    # Cache de pacotes apt
    apt-get clean
    apt-get autoremove -y
    log_ok "Cache apt limpo"
    
    # Arquivos temporários do sistema
    rm -rf /tmp/* 2>/dev/null || true
    log_ok "Temporários do sistema limpos"
    
    log_ok "Limpeza concluída."
}

# ─── Otimizar banco de dados ──────────────────────────────────────────────
otimizar_banco() {
    log_step "Otimizando banco de dados MariaDB"
    
    DB_ROOT_PASS="$(read_credential 'MARIADB_ROOT_PASSWORD')"
    if [[ -z "$DB_ROOT_PASS" ]]; then
        log_error "Senha root MariaDB não encontrada."
        return
    fi
    
    # Lista todos os bancos de usuário
    DATABASES="$(mysql -u root -p"${DB_ROOT_PASS}" \
        -e "SHOW DATABASES;" 2>/dev/null \
        | grep -Ev "^(Database|information_schema|performance_schema|sys|mysql)$" || true)"
    
    if [[ -z "$DATABASES" ]]; then
        log_warn "Nenhum banco de dados de usuário encontrado."
        return
    fi
    
    while IFS= read -r DB; do
        [[ -z "$DB" ]] && continue
        log_info "  Otimizando: ${DB}"
        mysqlcheck -u root -p"${DB_ROOT_PASS}" --optimize "$DB" 2>/dev/null || true
    done <<< "$DATABASES"
    
    log_ok "Otimização concluída."
}

# ─── Verificar segurança ──────────────────────────────────────────────────
verificar_seguranca() {
    log_step "Verificação de Segurança"
    echo ""
    
    # Portas abertas
    echo -e "  ${BOLD}${CYAN}▸ Portas abertas:${NC}"
    ss -tulpn | grep LISTEN | awk '{print "    " $5 " → " $7}' || log_warn "    Nenhuma porta encontrada."
    
    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Regras do Firewall (UFW):${NC}"
    ufw status numbered | tail -n +4 | sed 's/^/    /'
    
    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Banimentos ativos (Fail2ban):${NC}"
    if command -v fail2ban-client &>/dev/null; then
        BANNED_SSH="$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}' || echo "0")"
        echo -e "    SSH: ${BANNED_SSH} IPs banidos"
        if [[ "$BANNED_SSH" -gt 0 ]]; then
            fail2ban-client status sshd | grep "Banned IP" | sed 's/^/      /'
        fi
    else
        echo -e "    ${YELLOW}Fail2ban não instalado${NC}"
    fi
    
    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Últimos logins SSH:${NC}"
    last -n 5 | sed 's/^/    /'
    
    echo ""
    echo -e "  ${BOLD}${CYAN}▸ Atualizações de segurança pendentes:${NC}"
    apt-get update -qq
    SECURITY_UPDATES="$(apt-get upgrade -s 2>/dev/null | grep -i security | wc -l || echo "0")"
    if [[ "$SECURITY_UPDATES" -gt 0 ]]; then
        echo -e "    ${YELLOW}${SECURITY_UPDATES} atualizações de segurança disponíveis${NC}"
        echo -e "    ${YELLOW}Execute a opção 2 (Atualizar sistema) do menu${NC}"
    else
        echo -e "    ${GREEN}✓ Sistema atualizado${NC}"
    fi
    
    echo ""
}

# ─── Ver logs ─────────────────────────────────────────────────────────────
ver_logs() {
    local tipo="${1:-nginx}"
    case "$tipo" in
        nginx-error) tail -n 50 /var/log/nginx/error.log ;;
        nginx-access) tail -n 50 /var/log/nginx/access.log ;;
        php)   journalctl -u "php${PHP_VERSION}-fpm" -n 50 --no-pager ;;
        mysql) journalctl -u mariadb -n 50 --no-pager ;;
    esac
}

# ─── Menu principal ────────────────────────────────────────────────────────
while true; do
    echo ""
    echo -e "${BLUE}${BOLD}  ╔════════════════════════════════════════╗"
    echo -e "  ║      🛠   Manutenção do Servidor        ║"
    echo -e "  ╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Sistema${NC}"
    echo -e "    ${CYAN}1${NC})  Status dos serviços e recursos"
    echo -e "    ${CYAN}2${NC})  Atualizar sistema (apt upgrade)"
    echo -e "    ${CYAN}3${NC})  Limpar caches e temporários"
    echo -e "    ${CYAN}4${NC})  Verificar segurança"
    echo ""
    echo -e "  ${BOLD}Serviços${NC}"
    echo -e "    ${CYAN}5${NC})  Recarregar Nginx (sem derrubar conexões)"
    echo -e "    ${CYAN}6${NC})  Reiniciar Nginx"
    echo -e "    ${CYAN}7${NC})  Reiniciar PHP ${PHP_VERSION}-FPM"
    echo -e "    ${CYAN}8${NC})  Reiniciar MariaDB"
    echo ""
    echo -e "  ${BOLD}Banco de Dados${NC}"
    echo -e "    ${CYAN}9${NC})  Otimizar bancos MariaDB"
    echo -e "    ${CYAN}10${NC}) Logs MariaDB"
    echo ""
    echo -e "  ${BOLD}Logs${NC}"
    echo -e "    ${CYAN}11${NC}) Erros Nginx (últimas 50 linhas)"
    echo -e "    ${CYAN}12${NC}) Acessos Nginx (últimas 50 linhas)"
    echo -e "    ${CYAN}13${NC}) Logs PHP-FPM"
    echo -e "    ${CYAN}14${NC}) Banimentos ativos (Fail2ban SSH)"
    echo ""
    echo -e "  ${BOLD}Sites${NC}"
    echo -e "    ${CYAN}15${NC}) Listar sites ativos"
    echo -e "    ${CYAN}16${NC}) Criar novo site"
    echo -e "    ${CYAN}17${NC}) Desativar site"
    echo -e "    ${CYAN}18${NC}) Remover site (arquivos + config)"
    echo ""
    echo -e "  ${BOLD}Backup${NC}"
    echo -e "    ${CYAN}19${NC}) Fazer backup agora"
    echo -e "    ${CYAN}20${NC}) Restaurar backup"
    echo ""
    echo -e "    ${CYAN}0${NC})  Sair"
    echo ""
    read -rp "  ► Opção: " OPT

    case "$OPT" in
        1)  show_status ;;
        2)  atualizar_sistema ;;
        3)  limpar_caches ;;
        4)  verificar_seguranca ;;
        5)  nginx -t && nginx -s reload && log_ok "Nginx recarregado." || log_error "Erro na config Nginx." ;;
        6)  systemctl restart nginx   && log_ok "Nginx reiniciado." ;;
        7)  systemctl restart "php${PHP_VERSION}-fpm" && log_ok "PHP-FPM reiniciado." ;;
        8)  systemctl restart mariadb && log_ok "MariaDB reiniciado." ;;
        9)  otimizar_banco ;;
        10) ver_logs mysql ;;
        11) ver_logs nginx-error ;;
        12) ver_logs nginx-access ;;
        13) ver_logs php ;;
        14) fail2ban-client status sshd 2>/dev/null || log_warn "Fail2ban não disponível." ;;
        15) listar_sites ;;
        16) bash "${SCRIPT_DIR}/09-novo-site.sh" ;;
        17) desativar_site ;;
        18) remover_site ;;
        19) bash "${SCRIPT_DIR}/10-backup.sh" ;;
        20) bash "${SCRIPT_DIR}/11-restaurar.sh" ;;
        0)  log_info "Até mais!"; exit 0 ;;
        *)  log_warn "Opção inválida: ${OPT}" ;;
    esac
done
