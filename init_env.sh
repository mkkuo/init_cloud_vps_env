#!/bin/bash

# ======================== #
#   VPS 一鍵環境部署腳本    #
# ======================== #

# 使用者可編輯的參數區
MYSQL_ROOT_PASSWORD="changeMeStrongPwd"    # MariaDB root 密碼
DOMAIN="your.domain.com"                   # 網站網域
EMAIL="your@email.com"                     # Let's Encrypt 通知 Email
PHPMYADMIN_ALLOW_IP="10.20.30.40"      # 允許存取 phpMyAdmin 的 IP 或網段

# ======================== #
#      開始自動部署流程     #
# ======================== #

# 0. 必須 root 權限
if [ "$EUID" -ne 0 ]; then
  echo "❌ 請以 root 權限執行此腳本"
  exit 1
fi

echo "🚀 初始化 Oracle Cloud VPS 環境..."

# 1. 系統更新與基礎套件
echo "🔧 更新系統套件..."
dnf update -y

# 2. 安裝 EPEL & Remi repository
echo "📦 安裝 EPEL & Remi..."
dnf install -y epel-release
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
dnf module reset php -y
dnf module enable php:remi-8.1 -y

# 3. 安裝服務
echo "📦 安裝 Nginx, PHP, phpMyAdmin, MariaDB..."
dnf install -y nginx php php-fpm php-mysqlnd php-json php-gd php-mbstring php-xml php-cli php-common phpMyAdmin mariadb-server mariadb

# 啟動並設開機自動啟動
systemctl enable --now mariadb
systemctl enable --now nginx
systemctl enable --now php-fpm

# 4. 設定 MariaDB root 密碼
echo "🛡️ 設定 MariaDB root 密碼..."
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# 5. 安裝 Python3 與常用套件
echo "🐍 安裝 Python3 與 pip/套件..."
dnf install -y python3 python3-pip python3-devel
pip3 install --upgrade pip
pip3 install virtualenv flask requests

# 6. 網站目錄建立與權限
echo "📁 建立網站目錄..."
mkdir -p /var/www/html/myapp
echo "<?php phpinfo(); ?>" > /var/www/html/myapp/index.php
chown -R nginx:nginx /var/www/html/myapp

# 7. Nginx 設定（含 phpMyAdmin 限定 IP）
echo "📝 產生 Nginx 設定..."
cat <<EOF > /etc/nginx/conf.d/myapp.conf
server {
    listen 80;
    server_name ${DOMAIN};

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

        # 只允許指定 IP
        allow ${PHPMYADMIN_ALLOW_IP};
        deny all;
    }
}
EOF

# 8. 防火牆開啟（有 firewalld 才設定）
if systemctl is-active firewalld >/dev/null 2>&1; then
  echo "🔐 設定防火牆..."
  firewall-cmd --add-service=http --permanent
  firewall-cmd --add-service=https --permanent
  firewall-cmd --add-service=mysql --permanent
  firewall-cmd --reload
fi

# 9. 重啟 Nginx
echo "🔁 重新啟動 Nginx..."
nginx -t && systemctl restart nginx

# 10. 安裝與設定 Let's Encrypt 憑證
echo "🔒 安裝 certbot/Let's Encrypt..."
dnf install -y certbot python3-certbot-nginx

echo "🚀 申請並安裝憑證..."
certbot --nginx --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN"

# 11. 建立自動續期計劃
echo "🗓️ 建立 certbot 自動續期計畫任務..."
echo "0 3 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-auto-renew

echo "✅ Let's Encrypt SSL 憑證與自動續期設定完成！"

# 12. 完成提示
echo "✅ 初始化完成！"
echo "👉 可瀏覽 http://${DOMAIN}/ 來測試"
echo "👉 phpMyAdmin: http://${DOMAIN}/phpmyadmin (僅允許 ${PHPMYADMIN_ALLOW_IP})"
echo "👉 MariaDB root 密碼：${MYSQL_ROOT_PASSWORD}"
