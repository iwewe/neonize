# 🚨 Neonize Emergency Response Chatbot

> WhatsApp chatbot untuk sistem tanggap darurat bencana dengan integrasi n8n

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://python.org)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)

---

## 📖 Daftar Isi

- [Tentang Proyek](#-tentang-proyek)
- [Quick Install](#-quick-install)
- [Fitur](#-fitur)
- [Arsitektur](#-arsitektur)
- [Dokumentasi](#-dokumentasi)
- [Screenshots](#-screenshots)
- [Support](#-support)

---

## 🎯 Tentang Proyek

**Neonize Emergency Response Chatbot** adalah solusi lengkap untuk sistem tanggap darurat bencana menggunakan WhatsApp sebagai platform komunikasi. Sistem ini dirancang untuk membantu organisasi tanggap darurat (BPBD, PMI, dll) dalam:

- 📱 Menerima laporan bencana dari masyarakat secara real-time
- 🚨 Mengirim broadcast alert ke wilayah terdampak
- 👥 Koordinasi tim lapangan melalui grup WhatsApp
- 🤖 Helpdesk otomatis 24/7
- 📊 Dashboard monitoring & analytics

### Mengapa WhatsApp?

- ✅ Sudah familiar untuk mayoritas masyarakat Indonesia
- ✅ End-to-end encryption (aman & privat)
- ✅ Dukungan multimedia (foto, video, lokasi, dokumen)
- ✅ Penetrasi smartphone tinggi
- ✅ Bisa digunakan offline (pesan akan terkirim saat online)

---

## 🚀 Quick Install

### Instalasi Otomatis (Ubuntu 24.04)

Satu perintah untuk install lengkap:

```bash
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh | bash
```

Script akan otomatis:
- ✅ Install Docker & Docker Compose
- ✅ Install Python & dependencies
- ✅ Setup PostgreSQL, n8n, Grafana
- ✅ Generate QR code WhatsApp
- ✅ Konfigurasi environment

**Waktu instalasi**: ~10-15 menit

### Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| **OS** | Ubuntu 22.04 | Ubuntu 24.04 LTS |
| **RAM** | 2 GB | 4 GB+ |
| **Disk** | 10 GB | 20 GB+ |
| **CPU** | 2 cores | 4 cores+ |

### Setelah Install

1. **Scan QR Code** untuk koneksi WhatsApp
2. **Simpan Credentials** dari `~/neonize-emergency/credentials.txt`
3. **Test Bot** dengan kirim pesan: `"Ada banjir di daerah saya"`

**Dokumentasi lengkap**: [INSTALL.md](INSTALL.md)

---

## ✨ Fitur

### 1. 📥 Penerimaan Laporan Bencana

Warga dapat melaporkan kejadian bencana melalui WhatsApp:

- **Auto-detect** keyword bencana (banjir, gempa, kebakaran, dll)
- **Tracking ID** unik untuk setiap laporan
- **Location tracking** via GPS
- **Media documentation** (foto/video bukti)
- **Severity assessment** otomatis
- **Konfirmasi instant** ke pelapor

**Contoh Flow**:
```
Warga: "Ada banjir di Jl. Sunter setinggi 1 meter"
  ↓
Bot: ✅ LAPORAN DITERIMA
     ID: RPT20250115103000
     Kategori: BANJIR
     Tingkat: 🟡 3/5

     📍 Kirim lokasi Anda
     📸 Kirim foto/video
  ↓
Warga: [Share Location]
  ↓
Bot: ✅ Lokasi tersimpan
     Tim terdekat akan segera dihubungi
```

### 2. 📢 Broadcast Alert System

Kirim peringatan massal ke wilayah terdampak:

- **Targeted broadcast** per wilayah
- **Multi-format** (text, gambar, lokasi)
- **Template message** untuk berbagai jenis bencana
- **Delivery tracking**
- **Integration** dengan sensor/API external

**Contoh Alert**:
```
🌊 PERINGATAN BANJIR

Ketinggian air: 1.5 meter
Lokasi: Jakarta Utara

⚠️ SEGERA EVAKUASI
- Kelurahan Ancol
- Kelurahan Sunter Agung

Posko: GOR Sunter
Maps: [link]

Waktu: 15/01/2025 10:30
#EmergencyAlert #BPBD
```

### 3. 👥 Koordinasi Tim Lapangan

Grup WhatsApp otomatis untuk tim responden:

- **Auto-create** grup per misi
- **Command system** (/sitrep, /sos, /help)
- **Location tracking** anggota tim
- **Situation reports** terstruktur
- **Real-time updates** dari command center

**Commands**:
- `/sitrep` - Template laporan situasi
- `/sos` - Emergency help
- `/help` - Daftar perintah

### 4. 🤖 Helpdesk 24/7

Bot menjawab pertanyaan umum otomatis:

- **FAQ** tentang shelter, logistik, evakuasi, hotline
- **Keyword detection** untuk intent recognition
- **Multi-format response** (text, location, contact card)
- **Escalation** ke operator manusia

**Contoh**:
```
User: "Dimana lokasi pengungsian terdekat?"
  ↓
Bot: 📍 LOKASI SHELTER TERDEKAT

     1. GOR Sunter - Jl. Sunter Permai
     2. Balai Warga RW 08
     3. Gereja Santo Bellarminus

     [Send Location]
```

### 5. 📊 Monitoring & Analytics

Dashboard real-time untuk situational awareness:

- **Total laporan** masuk
- **Response time** rata-rata
- **Delivery success rate**
- **Active users** tracking
- **Heatmap** lokasi bencana
- **Trend analysis**

### 6. 🔗 Integrasi n8n

Workflow automation tanpa coding:

- **Webhook** dari/ke external systems
- **AI Analysis** (OpenAI, local LLM)
- **External APIs** (weather, maps, social media)
- **Database** operations
- **Conditional logic** & routing
- **Scheduled tasks**

**Contoh Workflow**:
```
Sensor API → n8n → Check Water Level
                ↓ (if > 1m)
            Send Alert via WhatsApp
                ↓
            Log to Database
                ↓
            Notify Admin Team
```

---

## 🏗️ Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                        Users Layer                          │
│                                                             │
│  📱 Citizens    👨‍🚒 Responders    👨‍💼 Admin    🌐 APIs      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   WhatsApp Network                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  Neonize Bridge API                         │
│               (FastAPI + Python)                            │
│  • REST API Endpoints                                       │
│  • Event Forwarding                                         │
│  • Message Processing                                       │
└────────────┬────────────────────┬──────────────────────────┘
             │                    │
    ┌────────▼────────┐  ┌────────▼──────────┐
    │   PostgreSQL    │  │      n8n          │
    │   (Database)    │  │  (Workflows)      │
    └────────┬────────┘  └────────┬──────────┘
             │                    │
             └────────┬───────────┘
                      │
             ┌────────▼────────┐
             │    Grafana      │
             │  (Monitoring)   │
             └─────────────────┘
```

### Tech Stack

| Layer | Technology |
|-------|------------|
| **WhatsApp Client** | Neonize (Python + Whatsmeow Go) |
| **API Framework** | FastAPI (async Python) |
| **Workflow Engine** | n8n (Node.js) |
| **Database** | PostgreSQL 15 |
| **Cache** | Redis 7 (optional) |
| **Monitoring** | Grafana + Prometheus |
| **Container** | Docker + Docker Compose |

---

## 📚 Dokumentasi

### Panduan Lengkap

| Dokumen | Deskripsi |
|---------|-----------|
| **[INSTALL.md](INSTALL.md)** | Panduan instalasi step-by-step |
| **[ANALISIS_CHATBOT_KEBENCANAAN.md](ANALISIS_CHATBOT_KEBENCANAAN.md)** | Analisis komprehensif 200+ halaman:<br>• 5 skenario implementasi<br>• Integrasi n8n<br>• Best practices<br>• Arsitektur teknis |
| **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** | Panduan deployment production:<br>• Docker deployment<br>• Manual deployment<br>• Monitoring setup<br>• Troubleshooting |

### Code Examples

```python
# Emergency Response Bot
from emergency_response_bot import EmergencyResponseBot

bot = EmergencyResponseBot(session_name="emergency_jakarta")
bot.ADMIN_NUMBERS = ['628123456789@s.whatsapp.net']
bot.run()

# Bot akan otomatis:
# - Detect laporan bencana
# - Tracking lokasi & media
# - Send konfirmasi
# - Notify admin
```

```python
# Broadcast Alert
from emergency_response_bot import EmergencyBroadcaster

broadcaster = EmergencyBroadcaster()
broadcaster.broadcast_alert(
    region='Jakarta Utara',
    alert_type='BANJIR',
    message='Air sungai Ciliwung meluap. Evakuasi segera!',
    target_jids=['628111111111@s.whatsapp.net']
)
```

```bash
# REST API
curl -X POST http://localhost:8000/send-message \
  -H "X-Api-Key: your-api-key" \
  -d '{
    "phone": "628123456789",
    "message": "⚠️ PERINGATAN: Banjir terdeteksi!"
  }'
```

### File Struktur

```
neonize-emergency/
├── examples/
│   ├── emergency_response_bot.py      # Main bot implementation
│   └── n8n_bridge.py                   # FastAPI REST API
├── n8n_workflows/
│   └── emergency_alert_workflow.json   # Sample n8n workflow
├── docker-compose.emergency.yml        # Docker stack
├── init-db.sql                         # Database schema
├── .env.example                        # Environment template
├── INSTALL.md                          # Installation guide
├── ANALISIS_CHATBOT_KEBENCANAAN.md    # Comprehensive analysis
└── DEPLOYMENT_GUIDE.md                 # Deployment guide
```

---

## 📸 Screenshots

### Bot Conversation
```
┌─────────────────────────────────────┐
│ User                         10:30  │
├─────────────────────────────────────┤
│ Ada banjir di Jl. Sunter            │
│ setinggi 50cm                       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Emergency Bot               10:30   │
├─────────────────────────────────────┤
│ ✅ LAPORAN DITERIMA                 │
│                                     │
│ ID: RPT20250115103000               │
│ Kategori: BANJIR                    │
│ Tingkat: 🟡 3/5                     │
│                                     │
│ 📍 Kirim lokasi Anda                │
│ 📸 Kirim foto/video                 │
└─────────────────────────────────────┘
```

### API Documentation (FastAPI)
```
GET  /health              Check API health
GET  /status              Bot status & info
POST /send-message        Send WhatsApp message
POST /send-broadcast      Broadcast to multiple
POST /create-group        Create emergency team
POST /check-whatsapp      Check number status
```

### n8n Workflow
```
[Webhook] → [Analyze Message] → [IF Emergency?]
                                      ├─ Yes → [Save DB]
                                      │         ├─ [Send Confirmation]
                                      │         └─ [Alert Admin]
                                      └─ No  → [Send FAQ]
```

---

## 🎮 Usage Examples

### Skenario 1: Warga Melapor Banjir

```
1. Warga kirim: "Ada banjir di Sunter setinggi 1 meter"
2. Bot auto-detect keyword "banjir"
3. Bot create report ID: RPT20250115103000
4. Bot simpan ke database
5. Bot kirim konfirmasi ke warga
6. Bot kirim poll: "Tingkat urgensi?"
7. Bot notify admin via WhatsApp
8. Warga kirim lokasi GPS
9. Bot update report dengan koordinat
10. Bot kirim ke sistem dispatch
```

### Skenario 2: Admin Broadcast Alert

```
1. Admin akses API: POST /send-broadcast
2. Input: region="Jakarta Utara", type="BANJIR"
3. API ambil daftar kontak di wilayah tersebut
4. API format alert message
5. API kirim ke semua kontak (rate-limited)
6. API track delivery status
7. API simpan ke broadcast_history table
8. n8n trigger workflow untuk follow-up
```

### Skenario 3: Koordinasi Tim Lapangan

```
1. Admin create grup: POST /create-group
2. Bot create WhatsApp group "Tim Evakuasi A"
3. Bot add members (relawan)
4. Bot set group description (misi, protokol)
5. Bot kirim welcome message + commands
6. Tim di lapangan kirim /sitrep
7. Bot reply template situation report
8. Tim isi dan kirim
9. Bot forward ke command center
10. Command center kirim update ke grup
```

---

## 🛠️ Development

### Local Development

```bash
# Clone repository
git clone -b claude/neonize-emergency-analysis-K1wGV https://github.com/iwewe/neonize.git
cd neonize

# Setup virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements-emergency.txt

# Copy environment
cp .env.example .env
nano .env

# Run bot
python examples/emergency_response_bot.py

# Run API (separate terminal)
python examples/n8n_bridge.py
```

### Docker Development

```bash
# Build and run
docker compose -f docker-compose.emergency.yml up --build

# View logs
docker compose -f docker-compose.emergency.yml logs -f

# Restart service
docker compose -f docker-compose.emergency.yml restart neonize_bridge

# Stop all
docker compose -f docker-compose.emergency.yml down
```

### Testing

```bash
# Run tests
pytest tests/

# Test API
curl http://localhost:8000/health

# Test database
docker exec -it emergency_postgres psql -U emergency -d emergency_db
```

---

## 🤝 Contributing

Kontribusi sangat diterima! Beberapa area yang bisa dibantu:

- 🐛 Bug reports & fixes
- ✨ Feature requests & implementation
- 📖 Documentation improvements
- 🌍 Translations (bahasa daerah)
- 🧪 Testing & QA
- 💡 Ideas & suggestions

### How to Contribute

1. Fork repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

---

## 📞 Support

Butuh bantuan? Ada beberapa cara:

- 📖 **Documentation**: Baca [INSTALL.md](INSTALL.md) dan [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- 🐛 **Issues**: [GitHub Issues](https://github.com/iwewe/neonize/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/iwewe/neonize/discussions)
- 📧 **Email**: (tambahkan email support)

---

## 📄 License

Project ini dilisensikan di bawah **Apache License 2.0** - lihat file [LICENSE](LICENSE) untuk detail.

---

## 🙏 Acknowledgments

Project ini dibangun dengan:

- [Neonize](https://github.com/krypton-byte/neonize) - WhatsApp library for Python
- [Whatsmeow](https://github.com/tulir/whatsmeow) - WhatsApp Web API in Go
- [n8n](https://n8n.io) - Workflow automation platform
- [FastAPI](https://fastapi.tiangolo.com) - Modern Python web framework
- [PostgreSQL](https://postgresql.org) - Reliable database
- [Grafana](https://grafana.com) - Analytics & monitoring

---

## 🌟 Showcase

Jika Anda menggunakan project ini, kami ingin mendengar cerita Anda!

- Kirim PR untuk menambahkan organisasi Anda di sini
- Share screenshots/demo
- Tulis blog post tentang pengalaman Anda

---

<div align="center">

**Dibuat dengan ❤️ untuk membantu masyarakat Indonesia**

[⬆ Kembali ke atas](#-neonize-emergency-response-chatbot)

</div>
