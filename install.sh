#!/bin/bash

# ===============================
# AUTO INSTALLER PHPMYADMIN + DB
# BY FAJAR OFFICIAL
# ===============================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Root check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Jalankan script sebagai root!${NC}"
   exit 1
fi

ASCII_ART="${PURPLE}
╔══════════════════════════════════════════╗
║    ███████╗ █████╗ ██╗      █████╗ ██████╗║
║    ██╔════╝██╔══██╗██║     ██╔══██╗██╔══██╗║
║    █████╗  ███████║██║     ███████║██████╔╝║
║    ██╔══╝  ██╔══██║██║     ██╔══██║██╔══██╗║
║    ██║     ██║  ██║███████╗██║  ██║██║  ██║║
║    ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝║
║${YELLOW}    Auto Installer phpMyAdmin + DB${PURPLE}     ║
╚══════════════════════════════════════════╝${NC}
"
show_header() {
    clear
    echo -e "$ASCII_ART"
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          MENU UTAMA - FAJAR OFFICIAL     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}\n"
}

# Function untuk loading animation
loading() {
    echo -ne "${YELLOW}Sedang memproses"
    for i in {1..3}; do
        echo -ne "."
        sleep 0.5
    done
    echo -e "${NC}\n"
}
while true; do
clear
show_header

echo -e "${WHITE}Pilihan Menu:${NC}\n"

echo "1) Install phpMyAdmin"
echo "2) Create Database User"
echo "3) Uninstall phpMyAdmin"
echo "4) Exit"
read -p "Pilih: " choice

case $choice in

1)
  read -p "Domain phpMyAdmin: " domain
loading
  install_dep


echo -e "${BLUE}[INFO]${NC} Membuat direktori phpMyAdmin..."
  mkdir /var/www/phpmyadmin && mkdir /var/www/phpmyadmin/tmp/ && cd /var/www/phpmyadmin


echo -e "${BLUE}[INFO]${NC} Mendownload phpMyAdmin..."
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-english.tar.gz
tar xvzf phpMyAdmin-latest-english.tar.gz
mv /var/www/phpmyadmin/phpMyAdmin-*-english/* /var/www/phpmyadmin

echo -e "${BLUE}[INFO]${NC} Mengatur permissions..."
chown -R www-data:www-data * 
mkdir config
chmod o+rw config
cp config.sample.inc.php config/config.inc.php
chmod o+w config/config.inc.php


echo -e "${BLUE}[INFO]${NC} Membuat SSL certificate..."
  certbot certonly --nginx -d $domain


echo -e "${BLUE}[INFO]${NC} Membuat konfigurasi Nginx..."
cat > /etc/nginx/sites-available/phpmyadmin.conf <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;

    root /var/www/phpmyadmin;
    index index.php;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;

    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  sudo ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf

  systemctl restart nginx

  echo -e "${GREEN}phpMyAdmin BERHASIL di install!${NC}"
;;

2)
  read -p "DB Username: " dbuser
  read -p "DB Host (contoh % atau IP): " dbhost
  read -sp "DB Password: " dbpass
  echo ""

  mysql -u root <<EOF
CREATE USER '$dbuser'@'$dbhost' IDENTIFIED BY '$dbpass';
GRANT ALL PRIVILEGES ON *.* TO '$dbuser'@'$dbhost';
FLUSH PRIVILEGES;
EOF

  echo -e "${GREEN}DATABASE USER BERHASIL DIBUAT${NC}"
;;

3)
 read -p "Domain Php:" phpweb
  rm -rf /var/www/phpmyadmin
  rm -f /etc/nginx/sites-available/phpmyadmin.conf
  rm -f /etc/nginx/sites-enabled/phpmyadmin.conf
sudo certbot delete $phpweb
  systemctl restart nginx

  echo -e "${GREEN}phpMyAdmin BERHASIL DIHAPUS${NC}"
;;

4)
  exit 0
;;

*)
  echo -e "${RED}Pilihan tidak valid${NC}"
;;
esac
done
