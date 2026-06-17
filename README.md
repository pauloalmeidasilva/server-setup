# Server Setup — Ubuntu Server

Kit completo de provisionamento e configuração automatizada para Ubuntu Server, ideal para ambiente de produção de serviços web.

## 📋 Funcionalidades

### Configuração Inicial
- ✅ **Sistema otimizado**: hostname, timezone, pacotes essenciais, firewall UFW
- ✅ **Segurança SSH**: acesso por chave pública, sem root, porta customizável, banner
- ✅ **Fail2ban**: proteção contra força bruta (SSH, Nginx)
- ✅ **Atualizações automáticas** de segurança (unattended-upgrades)

### Stack LEMP
- ✅ **Nginx**: configuração otimizada para performance e segurança
- ✅ **PHP-FPM 8.3**: múltiplos pools por site, OPcache, configuração segura
- ✅ **MariaDB**: instalação segura, sem acesso remoto, otimizada
- ✅ **Node.js 22 + PM2**: gerenciamento de aplicações Node.js

### Infraestrutura
- ✅ **Docker CE**: containerização (opcional)
- ✅ **SSL/TLS**: certificados autoassinados (wildcard para `*.empresa.local`)
- ✅ **mDNS (Avahi)**: acesso via domínio local (`empresa.local`)
- ✅ **Cockpit**: painel web de gerenciamento (porta 9090)

### Gestão de Sites
- ✅ **Criação automatizada**: virtual hosts Nginx + PHP pool + banco MariaDB
- ✅ **Gerenciamento**: listar, desativar, remover sites via menu
- ✅ **Logs individuais** por site

### Backup & Manutenção
- ✅ **Backup automático**: diário às 03:00 (cron)
- ✅ **Backup completo**: bancos de dados, arquivos, configurações
- ✅ **Restauração interativa**: escolha o backup desejado
- ✅ **Menu de manutenção**: 20+ operações de administração

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
BACKUP_DIR=/srv/backups

# Versões
PHP_VERSION=8.3
NODEJS_VERSION=22
```

### 3️⃣ Execute a instalação

```bash
chmod +x install.sh scripts/*.sh
sudo ./install.sh
```

A instalação completa leva **5-10 minutos** dependendo da conexão e hardware.

## 📦 Scripts Disponíveis

Todos os scripts estão em `scripts/` e são executados em ordem pelo `install.sh`:

| Script | Descrição |
|--------|-----------|
| `01-sistema.sh` | Configuração base: hostname, timezone, UFW, Fail2ban, atualizações |
| `02-ssh.sh` | Endurecimento SSH: chave pública, sem root, porta customizada |
| `03-webserver.sh` | Instala Nginx + PHP-FPM + MariaDB (stack LEMP) |
| `04-nodejs.sh` | Instala Node.js (via NodeSource) + PM2 |
| `05-docker.sh` | Instala Docker CE + Docker Compose Plugin |
| `06-ssl.sh` | Gera certificados SSL autoassinados (wildcard) |
| `07-mdns.sh` | Configura Avahi (mDNS) para acesso via domínio local |
| `08-cockpit.sh` | Instala Cockpit (painel web) |
| `09-novo-site.sh` | Cria novo site (interativo) |
| `10-backup.sh` | Executa backup completo + agenda cron |
| `11-restaurar.sh` | Restaura backup (interativo) |
| `12-manutencao.sh` | Menu de manutenção (20+ operações) |

### Execução Individual

Qualquer script pode ser executado individualmente:

```bash
sudo bash scripts/09-novo-site.sh
```

## 🌐 Criar um Novo Site

### Método 1: Script direto

```bash
sudo bash scripts/09-novo-site.sh
```

### Método 2: Menu de manutenção

```bash
sudo bash scripts/12-manutencao.sh
# Opção 16: Criar novo site
```

O script solicita:
- Nome do site (slug): `meusite`
- Domínio: `meusite.empresa.local` (padrão) ou customizado
- Ativar PHP? (S/n)
- Criar banco MariaDB? (S/n)

**Resultado:**
- ✅ Virtual host Nginx (`/etc/nginx/sites-enabled/meusite.conf`)
- ✅ Pool PHP-FPM dedicado (se habilitado)
- ✅ Certificado SSL específico
- ✅ Banco de dados + usuário (se habilitado)
- ✅ Estrutura de diretórios:
  ```
  /srv/sites/meusite/
  ├── public/        ← Arquivos do site
  └── logs/          ← Logs (access.log, error.log, php-error.log)
  ```

**Credenciais do banco** são salvas automaticamente em `/root/.server-credentials`.

## 🛠️ Menu de Manutenção

Execute o menu interativo:

```bash
sudo bash scripts/12-manutencao.sh
```

### Funcionalidades Disponíveis

**Sistema:**
1. Status dos serviços e recursos
2. Atualizar sistema (apt upgrade)
3. Limpar caches e temporários
4. Verificar segurança (portas, firewall, banimentos)

**Serviços:**
5. Recarregar Nginx (sem derrubar conexões)
6. Reiniciar Nginx
7. Reiniciar PHP-FPM
8. Reiniciar MariaDB

**Banco de Dados:**
9. Otimizar bancos MariaDB
10. Logs MariaDB

**Logs:**
11. Erros Nginx
12. Acessos Nginx
13. Logs PHP-FPM
14. Banimentos Fail2ban (SSH)

**Sites:**
15. Listar sites ativos
16. Criar novo site
17. Desativar site (mantém arquivos)
18. Remover site (arquivos + configuração)

**Backup:**
19. Fazer backup agora
20. Restaurar backup

## 💾 Backup & Restauração

### Backup Automático

Configurado para rodar **diariamente às 03:00** (cron).

**O que é salvo:**
- Dump de todos os bancos MariaDB (`.sql.gz`)
- Arquivos de todos os sites (`/srv/sites`)
- Configurações do servidor (Nginx, PHP, MariaDB, SSH)

**Localização:** `/srv/backups/YYYY-MM-DD_HH-MM-SS/`

**Retenção:** 7 dias (configurável em `KEEP_DAYS` no script)

### Backup Manual

```bash
sudo bash scripts/10-backup.sh
```

### Restauração

```bash
sudo bash scripts/11-restaurar.sh
```

O script lista backups disponíveis e solicita:
- Número do backup para restaurar
- Confirmação (digite `sim`)
- Opcionalmente: restaurar configurações do servidor

## 🔐 Credenciais

Todas as credenciais geradas são salvas automaticamente em:

```
/root/.server-credentials
```

**Formato:**
```
MARIADB_ROOT_PASSWORD=SuaSenhaSegura123!
DB_MEUSITE_NAME=meusite
DB_MEUSITE_USER=meusite
DB_MEUSITE_PASS=SenhaAleatoria20Chars
```

### Ver Credenciais

```bash
sudo cat /root/.server-credentials
```

## 🌍 Acessar o Servidor

### Via mDNS (domínio local)

Após a instalação, o servidor estará acessível na rede local via:

- **Cockpit (painel web)**: `https://empresa.local:9090`
- **Sites criados**: `https://meusite.empresa.local`
- **SSH**: `ssh usuario@empresa.local -p 22`

**Compatibilidade mDNS:**
- ✅ Linux (nativo)
- ✅ macOS (nativo)
- ⚠️ Windows: instalar Bonjour Print Services ou iTunes

### Via IP

```bash
# Descobrir o IP do servidor
ip addr show | grep 'inet '
```

Acesse via IP se mDNS não funcionar: `https://192.168.1.X:9090`

## 📁 Estrutura de Diretórios

```
/srv/
├── sites/              ← Todos os sites hospedados
│   ├── meusite/
│   │   ├── public/     ← Document root (index.php, index.html)
│   │   └── logs/       ← Logs do site
│   └── outrosite/
│       ├── public/
│       └── logs/
└── backups/            ← Backups automáticos
    ├── 2026-06-17_03-00-00/
    │   ├── databases/
    │   ├── sites.tar.gz
    │   └── configs.tar.gz
    └── 2026-06-16_03-00-00/

/etc/nginx/
├── sites-available/    ← Configurações dos sites
├── sites-enabled/      ← Sites ativos (symlinks)
└── snippets/           ← Includes reutilizáveis (SSL, headers)

/etc/ssl/local/         ← Certificados SSL autoassinados

/opt/scripts/           ← Scripts customizados (vazio inicialmente)

/var/log/php/           ← Logs PHP globais
```

## 🔧 Personalização

### Alterar Versão do PHP

1. Edite `.env`:
   ```bash
   PHP_VERSION=8.4
   ```

2. Re-execute o script:
   ```bash
   sudo bash scripts/03-webserver.sh
   ```

### Adicionar Extensões PHP

Edite `scripts/03-webserver.sh` e adicione na lista de pacotes:

```bash
"php${PHP_VERSION}-redis" \
"php${PHP_VERSION}-memcached" \
"php${PHP_VERSION}-ldap"
```

### Customizar Templates Nginx

Os templates estão em `templates/nginx/`:
- `nginx.conf`: configuração principal
- `ssl-params.conf`: parâmetros TLS/SSL
- `security-headers.conf`: cabeçalhos de segurança

Após alterar, aplique:

```bash
sudo cp templates/nginx/nginx.conf /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl reload nginx
```

## 🐛 Troubleshooting

### Erro: "Arquivo .env não encontrado"

```bash
cp .env.example .env
nano .env
```

### Erro: "SSH_PUBLIC_KEY não definida"

Gere uma chave SSH no seu computador:

```bash
ssh-keygen -t ed25519 -C "seu@email"
cat ~/.ssh/id_ed25519.pub
```

Copie a saída para `SSH_PUBLIC_KEY` no `.env`.

### Erro: "Senha MariaDB não encontrada"

```bash
sudo cat /root/.server-credentials | grep MARIADB_ROOT_PASSWORD
```

### Site não acessível via domínio local

1. Verifique se Avahi está rodando:
   ```bash
   sudo systemctl status avahi-daemon
   ```

2. Teste resolução DNS:
   ```bash
   ping -c 2 empresa.local
   ```

3. **Windows**: instale Bonjour ou use o IP diretamente.

### Cockpit não abre

1. Verifique status:
   ```bash
   sudo systemctl status cockpit.socket
   ```

2. Firewall:
   ```bash
   sudo ufw allow 9090/tcp
   ```

## 📊 Requisitos

- **Sistema Operacional**: Ubuntu Server 22.04 LTS ou 24.04 LTS
- **RAM mínima**: 2 GB (4 GB recomendado)
- **Disco**: 20 GB livres
- **Rede**: acesso à internet (para download de pacotes)

## 🤝 Contribuindo

Para melhorias ou correções:

1. Faça um fork do projeto
2. Crie uma branch: `git checkout -b minha-feature`
3. Commit: `git commit -m 'Adiciona nova feature'`
4. Push: `git push origin minha-feature`
5. Abra um Pull Request

## 📄 Licença

Este projeto é fornecido "como está", sem garantias. Use por sua conta e risco.

## 🙏 Créditos

- Baseado em boas práticas de segurança e performance
- Configurações inspiradas em projetos como Easyengine, ServerPilot, e documentação oficial

---

**Desenvolvido com ❤️ para facilitar o deploy de servidores web Ubuntu.**
