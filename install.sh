#!/bin/bash
# =============================================================================
# install.sh — Orquestrador principal do server-setup
# Uso: sudo bash install.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# shellcheck source=scripts/utils.sh
source "${SCRIPTS_DIR}/utils.sh"

check_root

# ─── Banner ────────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
cat <<'BANNER'
  ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗
  ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
  ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
  ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
  ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
  ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
        ███████╗███████╗████████╗██╗   ██╗██████╗
        ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
        ███████╗█████╗     ██║   ██║   ██║██████╔╝
        ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
        ███████║███████╗   ██║   ╚██████╔╝██║
        ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝
BANNER
echo -e "${NC}"
echo -e "  ${BOLD}Provisionamento de Servidor Ubuntu${NC} — v2.0"
echo -e "  $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

# ─── Verifica / carrega .env ───────────────────────────────────────────────
if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
    log_warn "Arquivo .env não encontrado. Copiando .env.example..."
    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    echo ""
    log_warn "Configure as variáveis antes de continuar:"
    echo -e "  ${BOLD}nano ${SCRIPT_DIR}/.env${NC}"
    echo ""
    read -rp "  Pressione Enter após editar o .env para continuar..."
fi

load_env "$SCRIPT_DIR"

# ─── Lista de etapas ───────────────────────────────────────────────────────
declare -a STEPS=(
    "01-sistema.sh:Configuração inicial do sistema"
    "02-ssh.sh:Endurecimento do SSH"
    "03-webserver.sh:Nginx + PHP ${PHP_VERSION:-8.3} + MariaDB"
    "04-nodejs.sh:Node.js ${NODEJS_VERSION:-22} + PM2"
    "05-docker.sh:Docker CE + Compose"
    "06-ssl.sh:Certificado SSL autoassinado"
    "07-mdns.sh:mDNS Avahi (${LOCAL_DOMAIN:-empresa.local})"
)

TOTAL=${#STEPS[@]}
CURRENT=0
FAILED=0

declare -a SUCCESS_LOG
declare -a ERROR_LOG

# ─── Executa etapas ────────────────────────────────────────────────────────
for entry in "${STEPS[@]}"; do
    script="${entry%%:*}"
    desc="${entry#*:}"
    ((CURRENT++))

    echo -e "\n${CYAN}${BOLD}[${CURRENT}/${TOTAL}]${NC} ${desc}"

    if [[ ! -f "${SCRIPTS_DIR}/${script}" ]]; then
        log_warn "Script não encontrado: ${script} — pulando."
        ERROR_LOG+=("- ${desc} (Script não encontrado)")
        ((FAILED++))
        continue
    fi

    if bash "${SCRIPTS_DIR}/${script}"; then
        log_ok "${desc} concluído."
        SUCCESS_LOG+=("- ${desc}")
    else
        log_error "${desc} falhou. Verifique os logs acima."
        ERROR_LOG+=("- ${desc}")
        ((FAILED++))
    fi
done

# ─── Resumo final ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== RESUMO DA INSTALAÇÃO ===${NC}"
echo ""

if (( ${#SUCCESS_LOG[@]} > 0 )); then
    echo -e "${GREEN}✓ Concluído com Sucesso:${NC}"
    for success in "${SUCCESS_LOG[@]}"; do
        echo -e "  ${GREEN}${success}${NC}"
    done
    echo ""
fi

if (( FAILED > 0 )); then
    echo -e "${RED}✗ Falhas Encontradas:${NC}"
    for err in "${ERROR_LOG[@]}"; do
        echo -e "  ${RED}${err}${NC}"
    done
    echo ""
    echo -e "${YELLOW}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║   ⚠  Concluído com ${FAILED} erro(s) — verifique os logs   ║"
    echo -e "  ╚══════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║       ✓  SERVIDOR CONFIGURADO COM SUCESSO            ║"
    echo -e "  ╚══════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "  ${BOLD}Acessos:${NC}"
echo -e "  🌐 Web:        https://${LOCAL_DOMAIN:-empresa.local}"
echo -e "  🔑 SSH:        ssh -p ${SSH_PORT:-22} <usuário>@${LOCAL_DOMAIN:-empresa.local}"
echo -e "  📂 Sites:      ${WEB_ROOT:-/srv/sites}"
echo ""
echo -e "  ${YELLOW}Credenciais salvas em: /root/.server-credentials${NC}"
echo ""
