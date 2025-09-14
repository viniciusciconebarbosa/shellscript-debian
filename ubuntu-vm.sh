#!/bin/bash

# Script de instalação e configuração para MySQL, Java, Nginx e Git
# Autor: Assistente
# Data: $(date)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se é root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Este script precisa ser executado como root ou com sudo"
        exit 1
    fi
}

# Função para atualizar o sistema
update_system() {
    print_status "Atualizando lista de pacotes..."
    apt-get update
    if [ $? -eq 0 ]; then
        print_success "Lista de pacotes atualizada"
    else
        print_error "Falha ao atualizar lista de pacotes"
        exit 1
    fi
}

# Função para instalar o MySQL
install_mysql() {
    print_status "Instalando MySQL Server..."
    apt-get install -y mysql-server
    
    if [ $? -eq 0 ]; then
        print_success "MySQL instalado com sucesso"
        
        # Configuração básica do MySQL
        print_status "Configurando MySQL..."
        
        # Criar arquivo de configuração personalizado
        cat > /etc/mysql/conf.d/custom.cnf << EOF
[mysqld]
bind-address = 0.0.0.0
default_authentication_plugin=mysql_native_password
max_connections = 100
wait_timeout = 600

[mysql]
default-character-set = utf8mb4

[mysqldump]
default-character-set = utf8mb4
EOF
        
        # Reiniciar MySQL para aplicar configurações
        systemctl restart mysql
        systemctl enable mysql
        
        # Configuração de segurança básica
        print_status "Executando configuração de segurança do MySQL..."
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"
        mysql -e "DELETE FROM mysql.user WHERE User='';"
        mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        mysql -e "DROP DATABASE IF EXISTS test;"
        mysql -e "FLUSH PRIVILEGES;"
        
        print_success "MySQL configurado e rodando na porta 3306"
    else
        print_error "Falha na instalação do MySQL"
        exit 1
    fi
}

# Função para instalar o Java
install_java() {
    print_status "Instalando Java (OpenJDK 11)..."
    apt-get install -y openjdk-11-jdk
    
    if [ $? -eq 0 ]; then
        print_success "Java instalado com sucesso"
        
        # Configurar variáveis de ambiente do Java
        print_status "Configurando variáveis de ambiente do Java..."
        
        JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
        
        # Adicionar ao /etc/environment
        if ! grep -q "JAVA_HOME" /etc/environment; then
            echo "JAVA_HOME=$JAVA_HOME" >> /etc/environment
        fi
        
        # Adicionar ao perfil do sistema
        cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$JAVA_HOME
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
        
        # Carregar variáveis imediatamente
        source /etc/environment
        source /etc/profile.d/java.sh
        
        print_success "Java configurado. JAVA_HOME: $JAVA_HOME"
        
        # Verificar instalação
        java -version
        javac -version
        
    else
        print_error "Falha na instalação do Java"
        exit 1
    fi
}

# Função para instalar o Nginx
install_nginx() {
    print_status "Instalando Nginx..."
    apt-get install -y nginx
    
    if [ $? -eq 0 ]; then
        print_success "Nginx instalado com sucesso"
        
        # Configuração básica do Nginx
        print_status "Configurando Nginx..."
        
        # Backup da configuração padrão
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
        
        # Configurações básicas
        cat > /etc/nginx/conf.d/custom.conf << EOF
# Configurações de desempenho
worker_processes auto;
worker_rlimit_nofile 100000;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    # Configurações básicas
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Logs
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
        
        # Criar site padrão
        cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
        
        # Testar configuração
        nginx -t
        
        if [ $? -eq 0 ]; then
            # Reiniciar Nginx
            systemctl restart nginx
            systemctl enable nginx
            
            # Configurar firewall (se estiver ativo)
            if command -v ufw >/dev/null 2>&1; then
                ufw allow 'Nginx HTTP'
                ufw allow 'Nginx HTTPS'
            fi
            
            print_success "Nginx configurado e rodando na porta 80"
        else
            print_error "Configuração do Nginx inválida"
            exit 1
        fi
        
    else
        print_error "Falha na instalação do Nginx"
        exit 1
    fi
}

# Função para instalar o Git
install_git() {
    print_status "Instalando Git..."
    apt-get install -y git
    
    if [ $? -eq 0 ]; then
        print_success "Git instalado com sucesso"
        
        # Configuração básica do Git
        print_status "Configurando Git..."
        
        # Configurações globais (ajuste conforme necessário)
        git config --global user.name "Seu Nome"
        git config --global user.email "seu.email@exemplo.com"
        git config --global core.editor "nano"
        git config --global init.defaultBranch "main"
        git config --global pull.rebase false
        
        print_success "Git configurado"
        git --version
        
    else
        print_error "Falha na instalação do Git"
        exit 1
    fi
}

# Função para criar arquivo de variáveis de ambiente
create_env_file() {
    print_status "Criando arquivo com variáveis de ambiente..."
    
    cat > /root/apps_environment.txt << EOF
# Variáveis de Ambiente - Aplicações Instaladas
# Gerado em: $(date)

## MySQL
PORT=3306
SOCKET=/var/run/mysqld/mysqld.sock
DATA_DIR=/var/lib/mysql
CONFIG_FILE=/etc/mysql/my.cnf

## Java
JAVA_HOME=$JAVA_HOME
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d '"' -f2)

## Nginx
PORT_HTTP=80
PORT_HTTPS=443
CONFIG_DIR=/etc/nginx
LOG_DIR=/var/log/nginx
WEB_ROOT=/var/www/html

## Git
GIT_VERSION=$(git --version | cut -d ' ' -f3)

## Comandos úteis:
# MySQL: systemctl status mysql
# Nginx: systemctl status nginx
# Java: java -version
# Git: git --version

## Portas em uso:
$(ss -tulpn | grep -E ':(3306|80|443)')
EOF
    
    print_success "Arquivo de variáveis criado: /root/apps_environment.txt"
}

# Função principal
main() {
    print_status "Iniciando instalação e configuração de aplicações..."
    echo "Aplicações a serem instaladas:"
    echo "1. MySQL Server"
    echo "2. Java (OpenJDK 11)"
    echo "3. Nginx"
    echo "4. Git"
    echo ""
    
    # Verificar se é root
    check_root
    
    # Atualizar sistema
    update_system
    
    # Instalar aplicações
    install_mysql
    install_java
    install_nginx
    install_git
    
    # Criar arquivo de variáveis
    create_env_file
    
    # Resumo final
    print_success "Instalação concluída com sucesso!"
    echo ""
    print_status "Resumo da instalação:"
    echo "MySQL: Rodando na porta 3306"
    echo "Java: JAVA_HOME=$JAVA_HOME"
    echo "Nginx: Rodando na porta 80"
    echo "Git: Versão $(git --version | cut -d ' ' -f3)"
    echo ""
    print_warning "Recomenda-se reiniciar o sistema ou executar: source /etc/environment"
    print_status "Arquivo com detalhes das variáveis: /root/apps_environment.txt"
}

# Executar função principal
main "$@"