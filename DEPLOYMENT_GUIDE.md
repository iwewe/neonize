# Panduan Deployment - Emergency Response Chatbot

## Daftar Isi
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment dengan Docker](#deployment-dengan-docker)
- [Manual Deployment](#manual-deployment)
- [Konfigurasi n8n](#konfigurasi-n8n)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Software Requirements
- **Docker** >= 20.10
- **Docker Compose** >= 2.0
- **Python** >= 3.10 (untuk manual deployment)
- **PostgreSQL** >= 14 (untuk manual deployment)

### WhatsApp Requirements
- Nomor WhatsApp yang **belum terhubung** ke WhatsApp Web/Desktop
- Smartphone dengan WhatsApp terinstall untuk scan QR code

---

## Quick Start

### 1. Clone Repository

```bash
cd /home/user/neonize
```

### 2. Setup Environment Variables

```bash
cp .env.example .env
nano .env
```

Edit `.env` dan sesuaikan:
```bash
# PostgreSQL
POSTGRES_PASSWORD=your-secure-password

# n8n
N8N_USER=admin
N8N_PASSWORD=your-n8n-password

# API
API_KEY=your-secret-api-key

# Admin numbers
ADMIN_NUMBERS=628123456789,628987654321
```

### 3. Start Services

```bash
docker-compose -f docker-compose.emergency.yml up -d
```

### 4. Check Services

```bash
docker-compose -f docker-compose.emergency.yml ps
```

Expected output:
```
NAME                  STATUS    PORTS
emergency_postgres    Up        0.0.0.0:5432->5432/tcp
emergency_n8n         Up        0.0.0.0:5678->5678/tcp
emergency_neonize     Up        0.0.0.0:8000->8000/tcp
emergency_grafana     Up        0.0.0.0:3000->3000/tcp
```

### 5. Connect WhatsApp

#### Option A: Via API
```bash
curl http://localhost:8000/health
```

Jika status `disconnected`, bot akan generate QR code di logs:

```bash
docker logs emergency_neonize -f
```

Scan QR code dengan WhatsApp di smartphone Anda:
1. Buka WhatsApp
2. Tap menu (⋮)
3. Pilih "Linked Devices"
4. Tap "Link a Device"
5. Scan QR code dari logs

#### Option B: Via Python Script
```bash
docker exec -it emergency_neonize python
```

```python
from neonize.client import NewClient

client = NewClient("emergency_bot")
client.connect()  # QR code akan muncul di terminal
```

### 6. Verify Connection

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

---

## Deployment dengan Docker

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Docker Network                 │
│                                                 │
│  ┌──────────────┐  ┌──────────────┐            │
│  │  PostgreSQL  │  │     n8n      │            │
│  │   :5432      │  │    :5678     │            │
│  └──────────────┘  └──────────────┘            │
│         ▲                 ▲                     │
│         │                 │                     │
│  ┌──────────────────────────────┐              │
│  │    Neonize Bridge API        │              │
│  │         :8000                │              │
│  └──────────────────────────────┘              │
│         ▲                                       │
└─────────┼───────────────────────────────────────┘
          │
    ┌─────▼─────┐
    │ WhatsApp  │
    │  Network  │
    └───────────┘
```

### Docker Compose Services

#### 1. PostgreSQL Database
- **Port**: 5432
- **Data**: Persistent volume `postgres_data`
- **Init**: Auto-run `init-db.sql` on first start

#### 2. n8n Workflow
- **Port**: 5678
- **UI**: http://localhost:5678
- **Auth**: Basic Auth (username/password dari .env)
- **Data**: Persistent volume `n8n_data`

#### 3. Neonize Bridge
- **Port**: 8000
- **API Docs**: http://localhost:8000/docs
- **Sessions**: Persistent volume `neonize_sessions`

#### 4. Grafana (Optional)
- **Port**: 3000
- **UI**: http://localhost:3000
- **Default**: admin/admin

### Common Docker Commands

```bash
# Start all services
docker-compose -f docker-compose.emergency.yml up -d

# Stop all services
docker-compose -f docker-compose.emergency.yml down

# View logs
docker-compose -f docker-compose.emergency.yml logs -f

# View logs for specific service
docker logs emergency_neonize -f

# Restart a service
docker-compose -f docker-compose.emergency.yml restart neonize_bridge

# Rebuild after code changes
docker-compose -f docker-compose.emergency.yml up -d --build

# Remove all data (WARNING: deletes volumes)
docker-compose -f docker-compose.emergency.yml down -v
```

---

## Manual Deployment

### 1. Install Dependencies

```bash
# System dependencies
sudo apt update
sudo apt install -y python3.11 python3-pip postgresql-14

# Python packages
pip install neonize fastapi uvicorn httpx pydantic python-dotenv
```

### 2. Setup Database

```bash
# Create database user
sudo -u postgres createuser -P emergency

# Create database
sudo -u postgres createdb -O emergency emergency_db

# Run init script
psql -U emergency -d emergency_db -f init-db.sql
```

### 3. Setup n8n

```bash
# Install n8n
npm install -g n8n

# Set environment
export DB_TYPE=postgresdb
export DB_POSTGRESDB_HOST=localhost
export DB_POSTGRESDB_DATABASE=n8n_db
export DB_POSTGRESDB_USER=emergency
export DB_POSTGRESDB_PASSWORD=your-password

# Start n8n
n8n start
```

### 4. Run Neonize Bridge

```bash
# Set environment
export SESSION_NAME=emergency_bot
export DATABASE_URL=postgresql://emergency:password@localhost:5432/emergency_db
export N8N_WEBHOOK_URL=http://localhost:5678/webhook/emergency
export API_KEY=your-api-key

# Run bridge
python examples/n8n_bridge.py
```

### 5. Setup as Systemd Service

Create `/etc/systemd/system/neonize-bridge.service`:

```ini
[Unit]
Description=Neonize Bridge API
After=network.target postgresql.service

[Service]
Type=simple
User=emergency
WorkingDirectory=/home/user/neonize
Environment="PATH=/usr/local/bin:/usr/bin"
Environment="SESSION_NAME=emergency_bot"
Environment="DATABASE_URL=postgresql://emergency:pass@localhost:5432/emergency_db"
Environment="N8N_WEBHOOK_URL=http://localhost:5678/webhook/emergency"
Environment="API_KEY=your-api-key"
ExecStart=/usr/bin/python3 examples/n8n_bridge.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable neonize-bridge
sudo systemctl start neonize-bridge
sudo systemctl status neonize-bridge
```

---

## Konfigurasi n8n

### 1. Access n8n UI

Open browser: http://localhost:5678

Login dengan credentials dari `.env`:
- Username: admin (default)
- Password: (dari N8N_PASSWORD)

### 2. Import Workflow

1. Click **"Workflows"** di sidebar
2. Click **"Import from File"**
3. Select `n8n_workflows/emergency_alert_workflow.json`
4. Click **"Import"**

### 3. Configure Credentials

#### PostgreSQL Credential

1. Go to **Credentials** → **New**
2. Select **Postgres**
3. Fill:
   - Host: `postgres` (Docker) atau `localhost` (manual)
   - Port: `5432`
   - Database: `emergency_db`
   - User: `emergency`
   - Password: (dari .env)
4. Save as "Emergency PostgreSQL"

#### HTTP Header Auth (untuk API)

1. Go to **Credentials** → **New**
2. Select **Header Auth**
3. Fill:
   - Name: `X-Api-Key`
   - Value: (API_KEY dari .env)
4. Save as "Neonize API Key"

### 4. Activate Workflow

1. Open imported workflow
2. Click **"Active"** toggle di top right
3. Verify webhook URL di Webhook node

### 5. Test Webhook

```bash
curl -X POST http://localhost:5678/webhook/emergency \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "message_received",
    "data": {
      "sender": "628123456789@s.whatsapp.net",
      "text": "Ada banjir di Sunter"
    }
  }'
```

---

## Testing

### 1. Test API Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Check status
curl -H "X-Api-Key: your-api-key" \
  http://localhost:8000/status

# Send message
curl -X POST http://localhost:8000/send-message \
  -H "X-Api-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "628123456789",
    "message": "Test message from bot!"
  }'

# Check WhatsApp
curl -X POST http://localhost:8000/check-whatsapp \
  -H "X-Api-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "phones": ["628123456789"]
  }'
```

### 2. Test Emergency Flow

#### Kirim laporan ke bot:
```
Dari nomor WhatsApp Anda, kirim ke bot:
"Ada banjir di Jl. Sunter setinggi 1 meter"
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

### 3. Test Broadcast

```bash
curl -X POST http://localhost:8000/send-broadcast \
  -H "X-Api-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "phones": ["628111111111", "628222222222"],
    "message": "⚠️ PERINGATAN: Ketinggian air mencapai 1.5m. Segera evakuasi!"
  }'
```

### 4. Test Database

```bash
# Connect to database
docker exec -it emergency_postgres psql -U emergency -d emergency_db

# Check reports
SELECT * FROM emergency_reports ORDER BY created_at DESC LIMIT 5;

# Check messages
SELECT * FROM message_log ORDER BY created_at DESC LIMIT 10;

# Exit
\q
```

---

## Monitoring

### 1. Logs

```bash
# All services
docker-compose -f docker-compose.emergency.yml logs -f

# Specific service
docker logs emergency_neonize -f
docker logs emergency_n8n -f
docker logs emergency_postgres -f

# With timestamp
docker logs --timestamps emergency_neonize

# Last 100 lines
docker logs --tail 100 emergency_neonize
```

### 2. Metrics (Grafana)

Access: http://localhost:3000

Default login: admin/admin

#### Add PostgreSQL Datasource:
1. Configuration → Data Sources → Add
2. Select PostgreSQL
3. Configure:
   - Host: postgres:5432
   - Database: emergency_db
   - User: emergency
   - Password: (from .env)
   - SSL Mode: disable
4. Save & Test

#### Create Dashboard:
1. Create → Dashboard
2. Add Panel
3. Sample queries:

**Total Reports**:
```sql
SELECT COUNT(*) FROM emergency_reports
```

**Reports by Category**:
```sql
SELECT category, COUNT(*) as count
FROM emergency_reports
GROUP BY category
ORDER BY count DESC
```

**Hourly Message Activity**:
```sql
SELECT
  DATE_TRUNC('hour', created_at) as time,
  COUNT(*) as messages
FROM message_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY time
ORDER BY time
```

### 3. Health Checks

Create monitoring script `monitor.sh`:

```bash
#!/bin/bash

# Check API health
API_STATUS=$(curl -s http://localhost:8000/health | jq -r '.status')

if [ "$API_STATUS" != "healthy" ]; then
  echo "❌ API is unhealthy!"
  # Send alert (e.g., email, Slack, etc.)
else
  echo "✅ API is healthy"
fi

# Check n8n
N8N_STATUS=$(curl -s http://localhost:5678/healthz)

if [ $? -ne 0 ]; then
  echo "❌ n8n is down!"
else
  echo "✅ n8n is up"
fi

# Check database
docker exec emergency_postgres pg_isready -U emergency

if [ $? -ne 0 ]; then
  echo "❌ Database is down!"
else
  echo "✅ Database is up"
fi
```

Run periodically:
```bash
chmod +x monitor.sh
watch -n 60 ./monitor.sh  # Every 60 seconds
```

---

## Troubleshooting

### Problem: Bot tidak terkoneksi ke WhatsApp

**Solution**:
1. Check logs:
   ```bash
   docker logs emergency_neonize -f
   ```

2. Verify QR code generated
3. Scan dengan WhatsApp yang benar
4. Pastikan nomor belum terhubung ke WA Web lain

### Problem: n8n workflow tidak trigger

**Solution**:
1. Check workflow active:
   - Open n8n UI
   - Verify "Active" toggle ON

2. Check webhook URL:
   ```bash
   docker logs emergency_n8n | grep webhook
   ```

3. Test webhook manually:
   ```bash
   curl -X POST http://localhost:5678/webhook/emergency \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```

### Problem: Database connection error

**Solution**:
1. Check PostgreSQL running:
   ```bash
   docker ps | grep postgres
   ```

2. Check credentials in `.env`

3. Test connection:
   ```bash
   docker exec -it emergency_postgres psql -U emergency -d emergency_db -c "SELECT 1"
   ```

### Problem: API returns 503

**Solution**:
1. Check if bot connected:
   ```bash
   curl http://localhost:8000/health
   ```

2. Restart bridge:
   ```bash
   docker-compose -f docker-compose.emergency.yml restart neonize_bridge
   ```

3. Re-scan QR if needed

### Problem: High memory usage

**Solution**:
1. Check container stats:
   ```bash
   docker stats
   ```

2. Limit resources in docker-compose:
   ```yaml
   neonize_bridge:
     # ... other config
     deploy:
       resources:
         limits:
           memory: 512M
   ```

3. Clear old logs:
   ```bash
   docker system prune
   ```

---

## Production Checklist

### Security
- [ ] Change all default passwords in `.env`
- [ ] Use strong API_KEY (min 32 characters)
- [ ] Enable HTTPS/SSL
- [ ] Setup firewall rules
- [ ] Regular security updates
- [ ] Database backups enabled

### Performance
- [ ] Setup Redis cache
- [ ] Configure rate limiting
- [ ] Database indexes optimized
- [ ] Log rotation configured
- [ ] Resource limits set

### Monitoring
- [ ] Grafana dashboards setup
- [ ] Alert rules configured
- [ ] Log aggregation (ELK/Loki)
- [ ] Uptime monitoring (UptimeRobot)
- [ ] Error tracking (Sentry)

### Backup
- [ ] Database auto-backup
- [ ] WhatsApp session backup
- [ ] Config files versioned
- [ ] Disaster recovery plan
- [ ] Backup restore tested

---

## Support

Untuk pertanyaan dan issues:
- GitHub: https://github.com/krypton-byte/neonize
- Documentation: `/home/user/neonize/docs/`
- Examples: `/home/user/neonize/examples/`

---

**Last Updated**: 2025-01-15
**Version**: 1.0.0
