#!/bin/bash

# Script para RHEL/CentOS/Fedora
# Instala MySQL, Java, Nginx, Git

# Para RHEL/CentOS 7/8/9, Fedora 36+

echo "Instalando repositórios EPEL..."
yum install -y epel-release

# Para Fedora
if [ -f /etc/fedora-release ]; then
    dnf install -y epel-release
fi

echo "Atualizando sistema..."
yum update -y

echo "Instalando MySQL..."
yum install -y mysql-community-server

echo "Instalando Java..."
yum install -y java-11-openjdk-devel

echo "Instalando Nginx..."
yum install -y nginx

echo "Instalando Git..."
yum install -y git

echo "Configurando variáveis de ambiente..."
JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=$JAVA_HOME" >> /etc/environment
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/environment
source /etc/environment

echo "Iniciando serviços..."
systemctl start mysqld
systemctl start nginx
systemctl enable mysqld
systemctl enable nginx

echo "Instalação concluída!"
echo "Java: $(java -version 2>&1 | head -n 1)"
echo "MySQL: $(mysql --version)"
echo "Nginx: $(nginx -v 2>&1)"
echo "Git: $(git --version)"