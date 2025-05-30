
# init_cloud_vps_env

本專案提供一鍵自動化部署 Oracle Cloud VPS 常用環境的腳本，包含 Nginx、PHP（含常用模組）、phpMyAdmin、MariaDB（MySQL 相容）、Python（含常用套件），同時整合 Let's Encrypt 憑證自動申請與續期，並強化安全性設定（如限制 phpMyAdmin 僅允許特定 IP 存取）。適用於 Oracle Cloud Linux 8/9 及同類型 CentOS/RedHat 環境。

## 特色與優點

- 一鍵全自動安裝 Nginx、PHP、MariaDB、Python、phpMyAdmin
- 預設強化安全，phpMyAdmin 僅允許自訂 IP 存取
- 支援 Let's Encrypt 憑證自動申請與自動續期
- 自動化設定 MariaDB root 密碼
- 系統套件與服務自動啟動、設定防火牆
- 適合 Oracle Cloud VM 或一般雲端 VPS

## 快速啟動

1. **編輯腳本開頭參數（可用文字編輯器開啟 `init_env.sh`，找到下列變數直接修改）**：

   ```bash
   MYSQL_ROOT_PASSWORD="自訂你的密碼"
   DOMAIN="your.domain.com"         # 你的網站網域
   EMAIL="user@example.com"         # Let's Encrypt 通知 Email
   PHPMYADMIN_ALLOW_IP="10.20.30.40"   # 允許存取 phpMyAdmin 的 IP
   ```

2. **儲存後，於終端機下執行腳本（需 root 權限）：**

   ```bash
   sudo bash init_env.sh
   ```

3. **安裝與設定全自動完成，過程會自動更新系統、安裝全部所需套件、建立網站目錄、設定 Nginx 及 MariaDB、設定 phpMyAdmin 存取限制、申請與套用 Let's Encrypt 憑證，最後自動啟動所有服務並輸出測試網址與 MariaDB 密碼提醒。**

## 目錄結構

```
init_env.sh         # 主自動化安裝腳本
README.md           # 本說明文件
```

## 腳本自動化內容（流程概述）

- 檢查 root 權限
- 系統套件更新與安裝必要 repository
- 一次安裝 Nginx、PHP（含常用模組）、phpMyAdmin、MariaDB（MySQL 相容）、Python3 與常用套件
- 自動設定 MariaDB root 密碼（變數可自訂）
- 建立網站根目錄與範例檔案
- 一次產生 Nginx 設定檔，包含主站點與 phpMyAdmin，phpMyAdmin 位置自動加上 IP 白名單（可自訂）
- 一次設定並開啟防火牆所需服務（HTTP、HTTPS、MySQL），避免重複 reload
- 自動啟動所有服務（Nginx、php-fpm、MariaDB）
- 安裝 certbot，自動申請 Let's Encrypt 憑證並套用，設定自動續期與定期 reload Nginx
- 完成後自動輸出可直接訪問的網址，以及 MariaDB root 密碼提醒

## 常見問題與使用建議

- **phpMyAdmin 想允許多個 IP？**  
  只需將變數 `PHPMYADMIN_ALLOW_IP` 改為 CIDR 格式（例如 `192.168.1.0/24`），或自行多行 allow，重跑一次腳本即可。
- **想改 root 密碼、網域、phpMyAdmin 安全規則？**  
  只要調整腳本變數，重新執行即可，自動覆蓋設定。
- **已安裝過的服務再執行會有問題嗎？**  
  大多數動作具 idempotent 性質（可重複執行），如服務已安裝會自動跳過或覆蓋，若遇特殊錯誤請先移除相關設定或重建環境。
- **Let’s Encrypt 憑證無法申請？**  
  請確保你指定的 `DOMAIN` 已經正確指向本 VM 的 Public IP，且 80/443 port 未被其他程式占用。

## 聯絡與貢獻

歡迎 issue、pull request 或來信聯繫：on@onsky.com.tw

---

**建議步驟**：  
複製本 README 與腳本後，僅需編輯腳本開頭參數，即可在 Oracle Cloud 或相容雲端 VM 完成全部常用服務的一鍵自動化建置！
