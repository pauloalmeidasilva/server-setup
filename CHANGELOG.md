# Changelog

Todas as mudanças notáveis deste projeto serão documentadas aqui.

## [2.0.0] - 2026-06-17

### 🎉 Reorganização Completa

#### Adicionado
- **Script 05-docker.sh**: Instalação completa do Docker CE com configurações de segurança
- **Script 11-restaurar.sh**: Sistema interativo de restauração de backups
- **Menu de manutenção expandido (12-manutencao.sh)**:
  - Limpeza de caches e temporários
  - Otimização de banco de dados
  - Verificação de segurança (portas, firewall, banimentos)
  - Gerenciamento de sites (desativar, remover)
  - 20 operações disponíveis

#### Melhorado
- **Documentação completa**:
  - README.md reescrito com exemplos práticos
  - QUICK_START.md para início rápido
  - Troubleshooting detalhado
- **Organização de scripts**:
  - Removidos scripts duplicados/obsoletos
  - Renumeração para ordem lógica de execução
  - Comentários detalhados em todos os scripts

#### Removido
- Scripts obsoletos: `01-pos-instalacao.sh`, `02-webserver.sh`, `03-docker.sh`, `04-novo-site.sh`, `05-backup.sh`, `06-restaurar.sh`
- Código duplicado e inconsistências

#### Ordem de Execução (Atualizada)
1. `01-sistema.sh` - Configuração inicial do sistema
2. `02-ssh.sh` - Segurança SSH
3. `03-webserver.sh` - Stack LEMP (Nginx + PHP + MariaDB)
4. `04-nodejs.sh` - Node.js + PM2
5. `05-docker.sh` - Docker CE (renomeado de 07-docker.sh)
6. `06-ssl.sh` - Certificados SSL (renomeado de 05-ssl.sh)
7. `07-mdns.sh` - mDNS/Avahi (renomeado de 06-mdns.sh)
8. `08-cockpit.sh` - Painel web Cockpit
9. `09-novo-site.sh` - Criação de sites
10. `10-backup.sh` - Sistema de backup
11. `11-restaurar.sh` - Restauração de backups
12. `12-manutencao.sh` - Menu de manutenção

---

## [1.0.0] - Data Anterior

### Implementação Inicial
- Estrutura base do projeto
- Scripts principais de instalação
- Templates Nginx
- Sistema de backup básico
- Criação automática de sites
- Integração com mDNS

---

## Notas de Versão

### Compatibilidade
- Ubuntu Server 22.04 LTS ✅
- Ubuntu Server 24.04 LTS ✅
- Debian 12 (não testado oficialmente)

### Dependências
- PHP 8.3 (configurável via `.env`)
- Node.js 22 (configurável via `.env`)
- MariaDB 10.6+
- Docker CE 24+
- Nginx 1.18+

### Próximas Versões (Planejado)

#### [2.1.0]
- [ ] Suporte a Let's Encrypt (Certbot)
- [ ] Backup remoto (S3, rsync)
- [ ] Integração com Fail2ban para Nginx
- [ ] Templates de sites (WordPress, Laravel, etc)

#### [2.2.0]
- [ ] Monitoramento com Netdata
- [ ] Cache Redis/Memcached
- [ ] Rate limiting avançado
- [ ] IPv6 configurado

#### [3.0.0]
- [ ] Suporte multi-servidor
- [ ] Balanceamento de carga
- [ ] CI/CD integrado
- [ ] Painel web customizado
