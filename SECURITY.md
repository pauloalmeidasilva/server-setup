# 🔒 Segurança e Boas Práticas

Este documento contém recomendações importantes de segurança para manter seu servidor protegido.

---

## ✅ Checklist de Segurança Pós-Instalação

### 1. Verificar SSH

- [ ] Autenticação por senha **DESATIVADA** (`PasswordAuthentication no`)
- [ ] Login root **DESATIVADO** (`PermitRootLogin no`)
- [ ] Chave pública configurada
- [ ] Banner de aviso legal ativo
- [ ] Porta SSH alterada (se exposto à internet)

**Verificar:**
```bash
sudo grep -E "^PasswordAuthentication|^PermitRootLogin|^Port" /etc/ssh/sshd_config
```

### 2. Firewall (UFW)

- [ ] UFW ativo e configurado
- [ ] Apenas portas necessárias abertas
- [ ] Rate limiting habilitado para SSH

**Verificar:**
```bash
sudo ufw status verbose
```

**Portas padrão abertas:**
- 22 (ou customizada) - SSH
- 80 - HTTP
- 443 - HTTPS
- 9090 - Cockpit

### 3. Fail2ban

- [ ] Fail2ban ativo
- [ ] SSH protegido (3 tentativas, banimento 24h)
- [ ] Nginx protegido

**Verificar:**
```bash
sudo systemctl status fail2ban
sudo fail2ban-client status sshd
```

### 4. Atualizações Automáticas

- [ ] Unattended-upgrades configurado
- [ ] Atualizações de segurança automáticas

**Verificar:**
```bash
sudo systemctl status unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades
```

### 5. SSL/TLS

- [ ] Certificados instalados
- [ ] TLS 1.2 e 1.3 apenas
- [ ] HSTS habilitado
- [ ] Cabeçalhos de segurança ativos

**Testar SSL:**
```bash
openssl s_client -connect empresa.local:443 -tls1_2
```

### 6. Banco de Dados

- [ ] Senha root forte
- [ ] Acesso restrito a localhost (`bind-address = 127.0.0.1`)
- [ ] Usuários específicos por site (sem `root` nas aplicações)
- [ ] Backup automático funcionando

**Verificar:**
```bash
sudo grep "^bind-address" /etc/mysql/mariadb.conf.d/*.cnf
```

### 7. PHP

- [ ] `expose_php = Off`
- [ ] `display_errors = Off`
- [ ] `open_basedir` restrito por site
- [ ] OPcache habilitado
- [ ] Sessões seguras (`session.cookie_httponly = 1`)

**Verificar:**
```bash
php -i | grep -E "expose_php|display_errors"
```

### 8. Nginx

- [ ] `server_tokens off` (oculta versão)
- [ ] Cabeçalhos de segurança (X-Frame-Options, CSP, etc)
- [ ] Rate limiting para login/API (quando aplicável)
- [ ] HTTPS redirect ativo

**Verificar:**
```bash
sudo nginx -T | grep server_tokens
curl -I https://empresa.local | grep -i "x-"
```

---

## 🔐 Recomendações Adicionais

### Senhas Fortes

**Nunca use:**
- Senhas padrão (`admin`, `123456`, etc)
- Senhas curtas (< 16 caracteres)
- Mesma senha em múltiplos locais

**Use:**
- Gerenciador de senhas (Bitwarden, 1Password, KeePass)
- Senhas geradas aleatoriamente (>20 caracteres)
- Senhas únicas por serviço

**Gerar senha forte:**
```bash
openssl rand -base64 32
```

### Chaves SSH

**Algoritmos recomendados:**
1. **Ed25519** (melhor): `ssh-keygen -t ed25519 -C "seu@email"`
2. RSA 4096: `ssh-keygen -t rsa -b 4096 -C "seu@email"`

**Proteja a chave privada:**
```bash
chmod 600 ~/.ssh/id_ed25519
```

**Nunca compartilhe** a chave privada (`id_ed25519`), apenas a pública (`id_ed25519.pub`).

### Backup de Credenciais

**Arquivo crítico:** `/root/.server-credentials`

```bash
# Fazer backup manual (criptografado)
sudo tar -czf ~/credentials-backup.tar.gz /root/.server-credentials
gpg -c ~/credentials-backup.tar.gz

# Guardar em local seguro (pen drive, cloud criptografado)
```

### Monitoramento

**Verificar logs regularmente:**

```bash
# Últimos logins SSH
sudo last | head

# Tentativas de login falhas
sudo lastb | head

# Logs do sistema
sudo journalctl -p err -b

# IPs banidos (Fail2ban)
sudo fail2ban-client status sshd
```

**Menu de manutenção** tem a opção "Verificar segurança":
```bash
sudo bash scripts/12-manutencao.sh
# Opção 4: Verificar segurança
```

---

## 🚨 Se o Servidor for Comprometido

### 1. Desconectar da rede

```bash
sudo ip link set eth0 down
```

### 2. Verificar processos suspeitos

```bash
ps aux | grep -v "\\["
netstat -tulpn
```

### 3. Verificar usuários logados

```bash
who
w
```

### 4. Desativar contas suspeitas

```bash
sudo usermod -L nome_usuario
```

### 5. Fazer backup forense

```bash
sudo dd if=/dev/sda of=/mnt/backup/disk-image.dd bs=4M
```

### 6. Reinstalar do zero

- Não confie em backups após comprometimento
- Reinstale o sistema operacional
- Mude todas as senhas
- Analise como ocorreu a invasão

---

## 📚 Recursos Adicionais

### Hardening Guides

- [CIS Ubuntu Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [OWASP Server Security Cheat Sheet](https://cheatsheetseries.owasp.org/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)

### Ferramentas de Auditoria

```bash
# Instalar Lynis (auditoria de segurança)
sudo apt install lynis
sudo lynis audit system

# Instalar rkhunter (detector de rootkits)
sudo apt install rkhunter
sudo rkhunter --check
```

### Testes Externos

- **SSL Labs**: https://www.ssllabs.com/ssltest/ (testar certificado)
- **Security Headers**: https://securityheaders.com/ (testar headers)
- **Shodan**: https://www.shodan.io/ (ver o que está exposto)

---

## 🔄 Manutenção Periódica

### Diariamente (automático)
- ✅ Backup às 03:00
- ✅ Atualizações de segurança

### Semanalmente (manual)
```bash
# Ver logs de segurança
sudo bash scripts/12-manutencao.sh
# Opção 4: Verificar segurança

# Verificar backups
ls -lh /srv/backups/

# Ver IPs banidos
sudo fail2ban-client status sshd
```

### Mensalmente (manual)
```bash
# Atualizar sistema completo
sudo bash scripts/12-manutencao.sh
# Opção 2: Atualizar sistema

# Limpar caches
sudo bash scripts/12-manutencao.sh
# Opção 3: Limpar caches e temporários

# Otimizar banco de dados
sudo bash scripts/12-manutencao.sh
# Opção 9: Otimizar bancos MariaDB

# Revisar usuários do sistema
cut -d: -f1,3 /etc/passwd | grep -E ":[0-9]{4,}$"
```

### Trimestralmente
- Rever políticas de firewall
- Atualizar chaves SSH (gerar novas, revogar antigas)
- Auditoria completa com Lynis
- Testar restauração de backup

---

## 📞 Em Caso de Dúvidas

Use o menu de manutenção:
```bash
sudo bash scripts/12-manutencao.sh
```

Consulte o [README.md](README.md) para troubleshooting.

---

**⚠️ LEMBRE-SE:** Segurança é um processo contínuo, não um estado final. Mantenha-se atualizado e vigilante!
