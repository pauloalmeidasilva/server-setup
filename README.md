# Server Setup — Ubuntu Server

Kit de provisionamento e configuração automatizada para Ubuntu Server, otimizado para uso em rede interna.

## 📋 Funcionalidades

### Configuração Inicial
- ✅ **Sistema otimizado**: hostname, timezone, pacotes essenciais, firewall UFW
- ✅ **Segurança SSH**: acesso por chave pública, sem root, porta customizável
- ✅ **Fail2ban**: proteção contra força bruta (SSH, Nginx) otimizado para ignorar tráfego de redes locais
- ✅ **Atualizações automáticas** de segurança (unattended-upgrades)

### Stack LEMP
- ✅ **Nginx**: configuração otimizada para performance e segurança
- ✅ **PHP-FPM 8.3**: configuração segura e otimizada
- ✅ **MariaDB**: instalação segura, sem acesso remoto
- ✅ **Node.js 22 + PM2**: gerenciamento de aplicações Node.js

### Infraestrutura
- ✅ **Docker CE**: containerização (opcional)
- ✅ **SSL/TLS**: certificados autoassinados
- ✅ **mDNS (Avahi)**: acesso via domínio local (`empresa.local`)

## 🚀 Instalação Rápida

### 1️⃣ Clone ou baixe o projeto

```bash
git clone <seu-repositorio> /tmp/server-setup
cd /tmp/server-setup
```

### 2️⃣ Configure as variáveis

```bash
cp .env.example .env
nano .env
```

**Principais variáveis:**

```bash
# Nome do servidor
SERVER_HOSTNAME=meu-servidor

# Domínio local (via mDNS)
LOCAL_DOMAIN=empresa.local

# Porta SSH (22 padrão, ou customize)
SSH_PORT=22

# Chave pública SSH (OBRIGATÓRIO para segurança máxima)
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3Nza... seu@email"

# Senha root MariaDB (deixe vazio para gerar automaticamente)
MARIADB_ROOT_PASSWORD=""

# Diretórios
WEB_ROOT=/srv/sites

# Versões
PHP_VERSION=8.3
NODEJS_VERSION=22
```

### 3️⃣ Execute a instalação

```bash
chmod +x install.sh scripts/*.sh
sudo ./install.sh
```

## 📦 Scripts Disponíveis

Todos os scripts estão em `scripts/` e são executados em ordem pelo `install.sh`:

| Script | Descrição |
|--------|-----------|
| `01-sistema.sh` | Configuração base: hostname, timezone, UFW, Fail2ban (ignora IPs locais), atualizações |
| `02-ssh.sh` | Endurecimento SSH: chave pública, sem root, porta customizada |
| `03-webserver.sh` | Instala Nginx + PHP-FPM + MariaDB (stack LEMP) |
| `04-nodejs.sh` | Instala Node.js (via NodeSource) + PM2 |
| `05-docker.sh` | Instala Docker CE + Docker Compose Plugin |
| `06-ssl.sh` | Gera certificados SSL autoassinados (wildcard) |
| `07-mdns.sh` | Configura Avahi (mDNS) para acesso via domínio local |

## 🌍 Acessar o Servidor

Após a instalação, o servidor estará acessível na rede local via:

- **Web**: `https://empresa.local`
- **SSH**: `ssh usuario@empresa.local -p 22`

**Compatibilidade mDNS:**
- ✅ Linux (nativo)
- ✅ macOS (nativo)
- ⚠️ Windows: instalar Bonjour Print Services ou iTunes, ou acessar diretamente pelo IP.

## 🔐 Credenciais

As credenciais do MariaDB geradas são salvas automaticamente em: `/root/.server-credentials`

Para ver:
```bash
sudo cat /root/.server-credentials
```

## 📊 Requisitos

- **Sistema Operacional**: Ubuntu Server 22.04 LTS ou 24.04 LTS
- **RAM mínima**: 2 GB
- **Rede**: acesso à internet para download de pacotes

---

**Desenvolvido com ❤️ para facilitar o deploy de servidores web Ubuntu.**
