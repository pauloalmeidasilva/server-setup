#!/bin/bash
# =============================================================================
# utils.sh — Funções utilitárias compartilhadas por todos os scripts
# =============================================================================

# ─── Cores e formatação ────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ─── Logging ───────────────────────────────────────────────────────────────
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${NC} $*"; }
log_error() { echo -e "${RED}[ERRO]${NC}  $*" >&2; }
log_step()  {
    echo -e "\n${BLUE}${BOLD}══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  ➜  $*${NC}"
    echo -e "${BLUE}${BOLD}══════════════════════════════════════════════${NC}"
}
log_ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; }

# ─── Verificações ──────────────────────────────────────────────────────────

# Garante execução como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root ou com sudo."
        exit 1
    fi
}

# Carrega variáveis do .env; recebe ROOT_DIR como argumento
load_env() {
    local root_dir="${1:?'load_env requer ROOT_DIR como argumento (ex: load_env \"\$ROOT_DIR\")'}"
    local env_file="${root_dir}/.env"

    if [[ ! -f "$env_file" ]]; then
        log_error "Arquivo .env não encontrado: $env_file"
        log_error "Copie .env.example para .env e configure as variáveis."
        exit 1
    fi

    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
}

# ─── Pacotes ───────────────────────────────────────────────────────────────

# Verifica se o pacote apt está instalado
is_installed() { dpkg -l "$1" 2>/dev/null | grep -q '^ii'; }

# Instala pacote apenas se ausente (silencioso se já instalado)
ensure_package() {
    local pkg="$1"
    if ! is_installed "$pkg"; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    else
        log_ok "$pkg já instalado."
    fi
}

# ─── Credenciais ───────────────────────────────────────────────────────────

# Gera senha aleatória de N caracteres
random_password() {
    local len="${1:-20}"
    tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c "$len"
    echo
}

# Salva credencial chave=valor em /root/.server-credentials (600)
save_credential() {
    local cred_file="/root/.server-credentials"
    if [[ ! -f "$cred_file" ]]; then
        touch "$cred_file"
        chmod 600 "$cred_file"
        echo "# Credenciais do servidor — server-setup" > "$cred_file"
        echo "# Gerado em: $(date '+%d/%m/%Y %H:%M:%S')" >> "$cred_file"
    fi
    # Evita duplicatas: remove linha existente antes de adicionar
    sed -i "/^${1}=/d" "$cred_file"
    echo "${1}=${2}" >> "$cred_file"
}

# Lê uma credencial do arquivo
read_credential() {
    local key="$1"
    grep "^${key}=" /root/.server-credentials 2>/dev/null | cut -d= -f2- || echo ""
}

# ─── Serviços ──────────────────────────────────────────────────────────────

# Aguarda serviço ficar ativo (timeout 30s)
wait_service() {
    local svc="$1"
    local count=0
    until systemctl is-active --quiet "$svc" 2>/dev/null; do
        sleep 1
        ((count++))
        if (( count >= 30 )); then
            log_error "Timeout aguardando o serviço: $svc"
            return 1
        fi
    done
}

# ─── Arquivos ──────────────────────────────────────────────────────────────

# Faz backup de um arquivo antes de modificar (não sobrescreve backup existente)
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local bak="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$bak"
        log_ok "Backup: $bak"
    fi
}
