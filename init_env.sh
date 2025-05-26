#!/bin/bash

# 檢查是否為 root 執行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 請以 root 權限執行此腳本"
  exit 1
fi

echo "🚀 開始初始化 Oracle Cloud VM 環境..."

# 1. 更新系統套件
echo "🔧 更新系統..."
dnf update -y

# 2. 安裝 EPEL & Remi 套件庫（提供 PHP & phpMyAdmin）
echo "📦 安裝 EPEL & Remi Repository..."
dnf install -y epel-release
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm

dnf module reset php -y
dnf module enable php:remi-8.1 -y

# 3. 安裝 Nginx、PHP、phpMyAdmin
echo "📦 安裝 Nginx、PHP、phpMyAdmin..."
dnf install -y nginx php php-fpm php-mysqlnd php-json php-gd php-mbstring php-xml php-cli php-common phpMyAdmin

# 4. 安裝 MariaDB（MySQL 相容）
echo "🐬 安裝 MariaDB..."
dnf install -y mariadb-server mariadb

# 啟動並設定 MariaDB 自動啟動
systemctl enable --now mariadb

# 設定 MariaDB root 密碼（請修改 'MyNewPassword' 為你自己的密碼）
echo "🛡️ 設定 MariaDB root 密碼..."
MYSQL_ROOT_PASSWORD="mypassword"
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# 5. 啟動 Nginx 與 PHP-FPM
systemctl enable --now nginx
systemctl enable --now php-fpm

# 6. 設定防火牆（Oracle Cloud 通常預設為開放，但仍可加上）
if systemctl is-active firewalld >/dev/null 2>&1; then
  echo "🔐 設定防火牆..."
  firewall-cmd --add-service=http --permanent
  firewall-cmd --add-service=https --permanent
  firewall-cmd --add-service=mysql --permanent
  firewall-cmd --reload
fi

# 7. 安裝 Python 與 pip
echo "🐍 安裝 Python 與套件..."
dnf install -y python3 python3-pip python3-devel
pip3 install --upgrade pip
pip3 install virtualenv flask requests

# 8. 建立 Nginx 的網站目錄
echo "📁 建立網站目錄..."
mkdir -p /var/www/html/myapp
echo "<?php phpinfo(); ?>" > /var/www/html/myapp/index.php
chown -R nginx:nginx /var/www/html/myapp

# 9. Nginx 設定檔（限制 phpMyAdmin 存取 IP）
cat <<EOF > /etc/nginx/conf.d/myapp.conf
server {
    listen 80;
    server_name localhost;

    root /var/www/html/myapp;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location /phpmyadmin {
        alias /usr/share/phpMyAdmin;
        index index.php;

        # ✅ 僅允許特定 IP 存取
        allow 220.133.228.156;
        deny all;
    }
}
EOF


# 10. 重新啟動 Nginx
echo "🔁 重新啟動 Nginx..."
systemctl restart nginx


# 11. Let's Encrypt SSL 憑證設定
DOMAIN="example.com"        # ✅ 請改成你自己的網域
EMAIL="user@example.com"      # ✅ 請填你可接收通知的 Email

echo "🔒 安裝 Certbot 與 Let's Encrypt 工具..."
dnf install -y certbot python3-certbot-nginx

echo "🌐 確認防火牆開放 80 / 443"
if systemctl is-active firewalld >/dev/null 2>&1; then
  firewall-cmd --add-service=http --permanent
  firewall-cmd --add-service=https --permanent
  firewall-cmd --reload
fi

echo "📜 建立初步 Nginx HTTP 設定以讓 certbot 執行..."
cat <<EOF > /etc/nginx/conf.d/${DOMAIN}.conf
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/html/myapp;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location /phpmyadmin {
        alias /usr/share/phpMyAdmin;
        index index.php;

        allow 192.168.1.0/24;
        deny all;
    }
}
EOF

# 重新載入 Nginx
nginx -t && systemctl reload nginx

echo "🚀 開始申請 Let's Encrypt 憑證..."
certbot --nginx --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN"

# 建立自動續期 cron 任務
echo "🗓️ 建立 certbot 自動續期計畫任務..."
echo "0 3 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-auto-renew

echo "✅ Let's Encrypt SSL 憑證安裝與自動更新設定完成！"


# 完成提示
echo "✅ 初始化完成！"
echo "👉 可瀏覽 http://<你的伺服器IP>/ 來測試"
echo "👉 PhpMyAdmin: http://<你的伺服器IP>/phpmyadmin"
echo "👉 MariaDB root 密碼：${MYSQL_ROOT_PASSWORD}"
