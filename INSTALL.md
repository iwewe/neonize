# Panduan Instalasi Neonize Emergency Response Chatbot

## 🚀 Quick Install (Satu Perintah)

### Metode 1: Install Lengkap (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh | bash
```

Script ini akan:
- ✅ Install Docker & Docker Compose
- ✅ Install Python 3.11+ & dependencies
- ✅ Clone repository
- ✅ Setup environment variables
- ✅ Start semua services (PostgreSQL, n8n, Grafana, Neonize)
- ✅ Generate QR code untuk WhatsApp

**Waktu instalasi**: ~10-15 menit (tergantung koneksi internet)

---

### Metode 2: Download & Inspect Dulu

Jika ingin melihat isi script sebelum dijalankan:

```bash
# Download script
wget https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh

# Inspect script
cat install.sh

# Make executable
chmod +x install.sh

# Run
./install.sh
```

---

## 📋 Prerequisites

### Sistem Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| OS | Ubuntu 22.04 | Ubuntu 24.04 LTS |
| RAM | 2 GB | 4 GB+ |
| Disk | 10 GB | 20 GB+ |
| CPU | 2 cores | 4 cores+ |
| Internet | Required | Broadband |

### Yang Dibutuhkan

1. **Server Ubuntu 24.04** (bisa VPS, local machine, atau VM)
2. **User dengan sudo access** (JANGAN run sebagai root)
3. **Internet connection** untuk download packages
4. **Nomor WhatsApp** yang belum terhubung ke WhatsApp Web/Desktop

---

## 🔧 Apa yang Akan Di-install?

Script akan menginstall dan mengkonfigurasi:

### System Packages
- Docker & Docker Compose (container runtime)
- Python 3.11+ (untuk development)
- Git, curl, wget (utilities)
- UFW firewall (optional)

### Docker Services
- **PostgreSQL 15** - Database untuk menyimpan laporan
- **n8n** - Workflow automation platform
- **Grafana** - Monitoring dashboard
- **Neonize Bridge** - WhatsApp bot API
- **Redis** (optional) - Caching layer

### Python Packages
- neonize (WhatsApp library)
- FastAPI (web framework)
- Uvicorn (ASGI server)
- SQLAlchemy (ORM)
- Dan 20+ dependencies lainnya

---

## 📖 Step-by-Step Installation

### Step 1: Prepare Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Reboot jika perlu
sudo reboot
```

### Step 2: Run Install Script

```bash
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh | bash
```

### Step 3: Ikuti Prompts

Script akan menanyakan:

1. **Admin WhatsApp Number**:
   ```
   Enter your admin WhatsApp number (e.g., 628123456789): 628123456789
   ```
   - Format: 62 + nomor tanpa 0 di depan
   - Contoh: 0812-3456-7890 → 628123456789

2. **Server Hostname/IP**:
   ```
   Enter your server hostname/IP (default: localhost): 192.168.1.100
   ```
   - Untuk local: `localhost`
   - Untuk VPS: masukkan IP public

3. **Auto-start on boot**:
   ```
   Do you want to auto-start services on boot? (y/N)
   ```
   - y = services akan start otomatis saat server reboot
   - N = manual start dengan docker compose

4. **Firewall configuration**:
   ```
   Do you want to configure UFW firewall? (y/N)
   ```
   - y = akan open port 8000, 5678, 3000
   - N = skip (atur firewall manual)

### Step 4: Scan QR Code

Setelah instalasi, script akan menampilkan QR code:

```
================================================
WhatsApp Connection Setup
================================================

To connect your WhatsApp account, you need to scan a QR code.

1. Wait 30 seconds for the bot to initialize...

2. View the QR code by running:
   docker logs emergency_neonize -f

3. In WhatsApp on your phone:
   - Open WhatsApp
   - Tap menu (⋮) → Linked Devices
   - Tap 'Link a Device'
   - Scan the QR code from the terminal

4. Press Ctrl+C to exit log view after scanning

Press Enter to view QR code logs...
```

**Di smartphone**:
1. Buka WhatsApp
2. Tap menu (⋮ di pojok kanan atas)
3. Pilih "Linked Devices"
4. Tap "Link a Device"
5. Scan QR code yang muncul di terminal
6. Tunggu sampai status "Connected"

### Step 5: Save Credentials

Script akan membuat file `credentials.txt` dengan isi:

```
==============================================================================
NEONIZE EMERGENCY RESPONSE - CREDENTIALS
==============================================================================
Generated: Mon Jan 15 10:30:00 WIB 2025

IMPORTANT: Save these credentials securely and delete this file!

PostgreSQL:
  Database: emergency_db
  User: emergency
  Password: xxxxxxxxxxxxxxxxxxxxxxxx

n8n:
  URL: http://192.168.1.100:5678
  Username: admin
  Password: xxxxxxxxxxxxxxxxxxxxxxxx

Neonize API:
  URL: http://192.168.1.100:8000
  API Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  Docs: http://192.168.1.100:8000/docs

Grafana:
  URL: http://192.168.1.100:3000
  Username: admin
  Password: xxxxxxxxxxxxxxxxxxxxxxxx

Admin WhatsApp: 628123456789

==============================================================================
DELETE THIS FILE AFTER SAVING THE CREDENTIALS!
==============================================================================
```

**PENTING**:
- Copy isi file ini ke password manager
- Simpan di tempat aman
- **DELETE FILE INI SETELAH DISIMPAN**

---

## ✅ Verifikasi Instalasi

### 1. Check Service Status

```bash
cd ~/neonize-emergency
docker compose -f docker-compose.emergency.yml ps
```

Expected output:
```
NAME                  STATUS    PORTS
emergency_postgres    Up        0.0.0.0:5432->5432/tcp
emergency_n8n         Up        0.0.0.0:5678->5678/tcp
emergency_neonize     Up        0.0.0.0:8000->8000/tcp
emergency_grafana     Up        0.0.0.0:3000->3000/tcp
emergency_redis       Up        0.0.0.0:6379->6379/tcp
```

### 2. Check API Health

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "healthy",
  "neonize_connected": true,
  "timestamp": "2025-01-15T10:30:00",
  "session": "emergency_bot"
}
```

### 3. Access Web Interfaces

| Service | URL | Default Login |
|---------|-----|---------------|
| **API Docs** | http://your-ip:8000/docs | No auth needed |
| **n8n** | http://your-ip:5678 | admin / (from credentials.txt) |
| **Grafana** | http://your-ip:3000 | admin / (from credentials.txt) |

### 4. Test Bot

Kirim pesan ke nomor WhatsApp yang terkoneksi:

```
Ada banjir di daerah Sunter setinggi 50cm
```

Expected response:
```
✅ LAPORAN DITERIMA

ID: RPT20250115103000
Kategori: BANJIR
Tingkat: 🟡 3/5
Waktu: 15/01/2025 10:30:00

Status: Sedang diverifikasi oleh tim

📍 LANGKAH SELANJUTNYA:
1. Kirim lokasi Anda (Share Location)
2. Kirim foto/video jika ada
3. Tunggu konfirmasi dari tim

Terima kasih atas laporannya! 🙏
```

---

## 🔧 Post-Installation Configuration

### 1. Setup n8n Workflows

1. Buka http://your-ip:5678
2. Login dengan credentials
3. Import workflow:
   - Workflows → Import from File
   - Select: `~/neonize-emergency/n8n_workflows/emergency_alert_workflow.json`
4. Configure credentials (lihat DEPLOYMENT_GUIDE.md)
5. Activate workflow

### 2. Setup Grafana Dashboard

1. Buka http://your-ip:3000
2. Login dengan credentials
3. Add PostgreSQL data source:
   - Configuration → Data Sources → Add
   - Host: `postgres:5432`
   - Database: `emergency_db`
   - User: `emergency`
   - Password: (from credentials.txt)
4. Create dashboard atau import template

### 3. Customize Bot Behavior

Edit file `~/neonize-emergency/.env`:

```bash
cd ~/neonize-emergency
nano .env
```

Yang bisa diubah:
- `ADMIN_NUMBERS` - Tambah nomor admin
- `EMERGENCY_KEYWORDS` - Tambah keyword bencana
- `SESSION_NAME` - Nama session bot

Setelah edit, restart:
```bash
docker compose -f docker-compose.emergency.yml restart
```

---

## 📱 Usage Examples

### Send Alert via API

```bash
curl -X POST http://localhost:8000/send-message \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "628123456789",
    "message": "⚠️ PERINGATAN: Banjir terdeteksi di wilayah Anda. Segera evakuasi!"
  }'
```

### Broadcast to Multiple Numbers

```bash
curl -X POST http://localhost:8000/send-broadcast \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "phones": ["628111111111", "628222222222", "628333333333"],
    "message": "🚨 ALERT: Gempa bumi terdeteksi. Jauhi bangunan!"
  }'
```

### Create Emergency Team Group

```bash
curl -X POST http://localhost:8000/create-group \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Tim Evakuasi Sektor A",
    "members": ["628111111111", "628222222222"]
  }'
```

---

## 🛠️ Management Commands

### View Logs

```bash
# All services
cd ~/neonize-emergency
docker compose -f docker-compose.emergency.yml logs -f

# Specific service
docker logs emergency_neonize -f
docker logs emergency_n8n -f
docker logs emergency_postgres -f
```

### Start/Stop Services

```bash
cd ~/neonize-emergency

# Start all
docker compose -f docker-compose.emergency.yml up -d

# Stop all
docker compose -f docker-compose.emergency.yml down

# Restart specific service
docker compose -f docker-compose.emergency.yml restart neonize_bridge

# Stop specific service
docker compose -f docker-compose.emergency.yml stop neonize_bridge
```

### Backup Database

```bash
# Backup
docker exec emergency_postgres pg_dump -U emergency emergency_db > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20250115.sql | docker exec -i emergency_postgres psql -U emergency -d emergency_db
```

### View QR Code Again

Jika koneksi terputus dan perlu scan ulang:

```bash
docker logs emergency_neonize -f
```

Atau restart service:

```bash
cd ~/neonize-emergency
docker compose -f docker-compose.emergency.yml restart neonize_bridge
docker logs emergency_neonize -f
```

---

## 🚨 Troubleshooting

### Problem: Docker permission denied

```
Error: permission denied while trying to connect to the Docker daemon socket
```

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Test
docker ps
```

### Problem: Port already in use

```
Error: bind: address already in use
```

**Solution**:
```bash
# Check what's using the port
sudo lsof -i :8000
sudo lsof -i :5678

# Kill the process or change port in docker-compose.yml
```

### Problem: QR code tidak muncul

**Solution**:
```bash
# Wait 30 seconds then check logs
docker logs emergency_neonize -f

# If still no QR, restart:
docker compose -f docker-compose.emergency.yml restart neonize_bridge
docker logs emergency_neonize -f
```

### Problem: Bot tidak merespon

**Solution**:
```bash
# Check if connected
curl http://localhost:8000/health

# Check logs
docker logs emergency_neonize --tail 50

# Restart service
docker compose -f docker-compose.emergency.yml restart neonize_bridge
```

### Problem: Database connection error

**Solution**:
```bash
# Check PostgreSQL status
docker compose -f docker-compose.emergency.yml ps postgres

# Check logs
docker logs emergency_postgres

# Restart PostgreSQL
docker compose -f docker-compose.emergency.yml restart postgres
```

---

## 🔄 Update Installation

Untuk update ke versi terbaru:

```bash
cd ~/neonize-emergency

# Backup first
docker compose -f docker-compose.emergency.yml down
cp -r ~/neonize-emergency ~/neonize-emergency.backup

# Pull latest changes
git pull origin claude/neonize-emergency-analysis-K1wGV

# Rebuild containers
docker compose -f docker-compose.emergency.yml up -d --build

# Check logs
docker compose -f docker-compose.emergency.yml logs -f
```

---

## 🗑️ Uninstall

Untuk uninstall complete:

```bash
# Stop and remove containers
cd ~/neonize-emergency
docker compose -f docker-compose.emergency.yml down -v

# Remove installation directory
rm -rf ~/neonize-emergency

# Remove systemd service (if created)
sudo systemctl disable neonize-emergency
sudo rm /etc/systemd/system/neonize-emergency.service
sudo systemctl daemon-reload

# Optional: Remove Docker
sudo apt remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker
```

---

## 📚 Next Steps

Setelah instalasi berhasil:

1. ✅ Baca [ANALISIS_CHATBOT_KEBENCANAAN.md](ANALISIS_CHATBOT_KEBENCANAAN.md) untuk skenario penggunaan
2. ✅ Baca [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) untuk konfigurasi production
3. ✅ Setup n8n workflows
4. ✅ Customize bot behavior di `.env`
5. ✅ Setup monitoring & alerts
6. ✅ Test dengan dummy data

---

## 💬 Support

Butuh bantuan?
- 📖 Documentation: `/home/user/neonize/docs/`
- 🔍 Examples: `/home/user/neonize/examples/`
- 🐛 Issues: https://github.com/iwewe/neonize/issues
- 📧 Email: (tambahkan email support)

---

## 📝 License

Apache 2.0 - See [LICENSE](LICENSE) file

---

**Last Updated**: 2025-01-15
