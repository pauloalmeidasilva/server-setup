# 🚀 Início Rápido — Server Setup

## Instalação em 5 Minutos

### 1. Prepare o `.env`

```bash
cd /caminho/do/server-setup
cp .env.example .env
nano .env
```

**Mínimo obrigatório:**

```bash
SERVER_HOSTNAME=meu-servidor
LOCAL_DOMAIN=empresa.local
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3Nza... seu@email"
```

### 2. Execute a instalação

```bash
chmod +x install.sh scripts/*.sh
sudo ./install.sh
```

**Duração:** 5-10 minutos

---

## O que foi instalado?

- ✅ Sistema otimizado (firewall, atualizações automáticas)
- ✅ SSH seguro (chave pública, sem root)
- ✅ Nginx + PHP 8.3 + MariaDB
- ✅ Node.js 22 + PM2
- ✅ Docker
- ✅ SSL autoassinado
- ✅ mDNS (`empresa.local`)
- ✅ Cockpit (painel web)
- ✅ Backup automático diário

---

## Próximos Passos

### 📌 1. Acessar o painel web

```
https://empresa.local:9090
```

**Login:** use o usuário e senha do sistema Ubuntu

### 📌 2. Criar seu primeiro site

```bash
sudo bash scripts/09-novo-site.sh
```

**Ou via menu:**

```bash
sudo bash scripts/12-manutencao.sh
# Opção 16: Criar novo site
```

### 📌 3. Ver credenciais do banco

```bash
sudo cat /root/.server-credentials
```

### 📌 4. Fazer backup manual

```bash
sudo bash scripts/10-backup.sh
```

---

## Comandos Úteis

### Menu de Manutenção

```bash
sudo bash scripts/12-manutencao.sh
```

**20+ operações disponíveis:**
- Status dos serviços
- Atualizar sistema
- Listar/criar/remover sites
- Ver logs
- Backup/restauração
- Otimizar banco de dados
- Verificar segurança

### Recarregar Nginx (sem downtime)

```bash
sudo nginx -t && sudo nginx -s reload
```

### Ver sites ativos

```bash
ls -l /etc/nginx/sites-enabled/
```

### Ver logs de um site

```bash
sudo tail -f /srv/sites/meusite/logs/error.log
```

### Reiniciar serviços

```bash
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm
sudo systemctl restart mariadb
```

---

## Acessar o Servidor

### Via domínio local (mDNS)

- **Cockpit:** `https://empresa.local:9090`
- **Site:** `https://meusite.empresa.local`
- **SSH:** `ssh usuario@empresa.local`

### Via IP

```bash
# Descobrir IP do servidor
ip addr show | grep 'inet '
```

Acesse via: `https://192.168.1.X:9090`

---

## Troubleshooting Rápido

### SSH não conecta

```bash
# Verificar porta SSH
sudo grep "^Port" /etc/ssh/sshd_config

# Status do serviço
sudo systemctl status sshd

# Firewall
sudo ufw status
```

### Site não funciona

```bash
# Testar configuração Nginx
sudo nginx -t

# Ver logs de erro
sudo tail -f /var/log/nginx/error.log

# Status do PHP-FPM
sudo systemctl status php8.3-fpm
```

### Banco não conecta

```bash
# Status MariaDB
sudo systemctl status mariadb

# Testar login
mysql -u root -p

# Ver credenciais
sudo cat /root/.server-credentials
```

### mDNS não resolve

```bash
# Status Avahi
sudo systemctl status avahi-daemon

# Testar resolução
ping -c 2 empresa.local

# Se falhar, use o IP direto
```

---

## Estrutura de Diretórios

```
/srv/sites/              ← Seus sites aqui
/srv/backups/            ← Backups automáticos
/etc/nginx/sites-enabled/ ← Configurações Nginx
/root/.server-credentials ← Senhas e credenciais
```

---

## Precisa de Ajuda?

Consulte o [README.md](README.md) completo para documentação detalhada.

**Principais tópicos:**
- Criação de sites
- Backup e restauração
- Personalização
- Troubleshooting avançado
