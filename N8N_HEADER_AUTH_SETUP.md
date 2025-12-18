# Setup Header Auth Credential di n8n

## ❓ Apa itu Header Auth?

**Header Auth** adalah credential untuk autentikasi API menggunakan HTTP header. Dalam workflow Emergency Response Bot, credential ini digunakan oleh node **"Send Auto Reply"** untuk:

1. **Memanggil API neonize** di: `http://emergency_neonize:8000/send-message`
2. **Autentikasi dengan header**: `X-Api-Key: <your-api-key>`
3. **Mengirim pesan WhatsApp** sebagai balasan otomatis ke pelapor emergency

**Tanpa credential ini**, node "Send Auto Reply" tidak bisa mengirim pesan balik ke WhatsApp.

---

## 🔑 Langkah 1: Cari API Key di Server

Di server Anda, jalankan command ini untuk melihat API_KEY:

```bash
cd ~/neonize-emergency
cat .env | grep API_KEY
```

**Output akan seperti:**
```
API_KEY=emergency_api_key_12345
```

**Catat value-nya** (contoh: `emergency_api_key_12345`). Anda akan memasukkan ini ke n8n.

---

## 🔧 Langkah 2: Buat Credential di n8n

### A. Buka Menu Credentials

1. **Login ke n8n**: `http://IP-SERVER:5678`

2. **Klik "Credentials"** di sidebar kiri

3. **Klik tombol "+ Add Credential"** di kanan atas

### B. Pilih Credential Type

1. **Di kotak pencarian**, ketik: `header auth`

2. **Pilih "Header Auth"** dari hasil pencarian

### C. Isi Form Credential

Anda akan melihat form dengan 3 field:

#### Field 1: Credential Name
- **Isi**: `Neonize API Key` (atau nama lain yang Anda inginkan)
- **Fungsi**: Hanya untuk label, memudahkan Anda mengenali credential ini

#### Field 2: Name (Header Name)
- **Isi**: `X-Api-Key`
- **Fungsi**: Nama header yang akan dikirim ke API
- **PENTING**: Harus **PERSIS** `X-Api-Key` (case-sensitive!)

#### Field 3: Value (Header Value)
- **Isi**: Paste API key yang Anda dapat dari step 1
- **Contoh**: `emergency_api_key_12345`
- **Fungsi**: Nilai header untuk autentikasi

**Contoh Form Terisi:**
```
┌─────────────────────────────────────────────┐
│ Credential Name                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Neonize API Key                         │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Name                                        │
│ ┌─────────────────────────────────────────┐ │
│ │ X-Api-Key                               │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Value                                       │
│ ┌─────────────────────────────────────────┐ │
│ │ emergency_api_key_12345                 │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│          [Save]                             │
└─────────────────────────────────────────────┘
```

4. **Klik tombol "Save"**

---

## 📝 Langkah 3: Assign Credential ke Node

### A. Kembali ke Workflow

1. **Klik "Workflows"** di sidebar kiri

2. **Buka workflow** "Emergency Response Bot"

### B. Update Node "Send Auto Reply"

1. **Klik node "Send Auto Reply"** (node HTTP Request terakhir)

2. **Di panel kanan**, scroll ke bagian **"Credentials"**

3. **Anda akan melihat:**
   ```
   Credentials
   ┌─────────────────────────────────────────┐
   │ Header Auth                             │
   │ [Select Credential ▼]                   │
   └─────────────────────────────────────────┘
   ```

4. **Klik dropdown**, pilih **"Neonize API Key"** (credential yang baru Anda buat)

5. **Klik "Save"** di kanan atas workflow

---

## ✅ Langkah 4: Verifikasi

### A. Check Warning

1. **Perhatikan node "Send Auto Reply"**

2. **Warning merah harus hilang:**
   - ❌ Before: "Issues: - Credentials for 'Header Auth' are not set."
   - ✅ After: Tidak ada warning

### B. Activate Workflow

1. **Di kanan atas workflow**, ada toggle **"Inactive"**

2. **Klik toggle** untuk activate → Berubah jadi **"Active"** (hijau)

---

## 🧪 Test Workflow

### Test 1: Manual Execution

1. **Klik node "Webhook Emergency"** (node pertama)

2. **Klik "Test"** di panel kanan

3. **Anda akan melihat**: "Waiting for test webhook call..."

4. **Di terminal server**, kirim test request:

```bash
curl -X POST http://localhost:5678/webhook-test/emergency \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "message_received",
    "timestamp": "2025-12-18T10:00:00",
    "data": {
      "message_id": "test123",
      "sender": "628123456789@s.whatsapp.net",
      "sender_name": "Test User",
      "chat": "628123456789@s.whatsapp.net",
      "is_group": false,
      "text": "Ada banjir besar di daerah saya!"
    }
  }'
```

5. **Di n8n**, workflow akan execute dan Anda bisa lihat data di setiap node

### Test 2: Real Message

1. **Pastikan workflow Active** (toggle hijau)

2. **Kirim pesan** ke nomor WhatsApp bot:
   ```
   Ada banjir besar di daerah saya, air sudah setinggi 1 meter!
   ```

3. **Check n8n Executions:**
   - Klik "Executions" di sidebar
   - Lihat list executions
   - Klik execution terakhir untuk lihat detail

4. **Bot harus auto-reply:**
   ```
   🌊 *LAPORAN DITERIMA*

   ID Laporan: RPT-1734567890123
   Jenis: FLOOD
   Tingkat: ⭐⭐⭐⭐ (4/5)
   Waktu: 18/12/2025 17:30:45

   ✅ Tim emergency response telah menerima laporan Anda.
   📞 Kami akan segera menghubungi untuk verifikasi.

   Tetap tenang dan ikuti instruksi petugas!
   ```

---

## 🐛 Troubleshooting

### Error: "Authentication failed"

**Check:**
1. API Key correct? Compare dengan value di `.env` file
2. Header name exactly `X-Api-Key`? (case-sensitive)

**Fix:**
```bash
# Di server, verify API key
cd ~/neonize-emergency
grep API_KEY .env

# Update credential di n8n jika berbeda
```

### Error: "Could not reach the service"

**Penyebab**: URL endpoint salah atau service neonize down

**Check:**
```bash
# Verify neonize service running
docker ps | grep emergency_neonize

# Check health endpoint
curl http://localhost:8000/health
```

**Expected**: `"neonize_connected": true`

### Warning: "n8n webhook returned 404" (di neonize logs)

**Meaning**: Ini WARNING NORMAL sebelum workflow active!

**Penjelasan**:
- Neonize bot mencoba forward message ke n8n
- Webhook belum active → 404
- Setelah workflow active → no more 404

---

## 📊 Flow Diagram

```
WhatsApp Message
      ↓
Neonize Bot receives
      ↓
Forward to n8n via webhook
      ↓
n8n: Process Message node
      ↓
n8n: Filter Emergency Only
      ↓
n8n: Save to PostgreSQL
      ↓
n8n: Generate Auto Reply
      ↓
n8n: Send Auto Reply (HTTP Request)
      ↓
      ├─ URL: http://emergency_neonize:8000/send-message
      ├─ Header: X-Api-Key: <your-api-key>  ← Credential digunakan di sini!
      └─ Body: {phone, message}
      ↓
Neonize API sends WhatsApp message
      ↓
User receives auto-reply
```

---

## 🔐 Security Notes

### Jangan Share API Key!

- API Key adalah **secret**, jangan commit ke Git
- Jangan screenshot atau share di public
- Gunakan `.env` file yang di-gitignore

### Rotate API Key (Optional)

Jika API key ter-expose, ganti:

```bash
cd ~/neonize-emergency
nano .env

# Update line:
API_KEY=new_secure_key_67890

# Restart services
docker compose -f docker-compose.emergency.yml restart

# Update credential di n8n dengan key baru
```

---

## ✅ Checklist

Setelah setup selesai, pastikan:

- [ ] API Key didapat dari `.env` file
- [ ] Credential "Header Auth" dibuat di n8n
- [ ] Header Name: `X-Api-Key`
- [ ] Header Value: API key dari `.env`
- [ ] Credential assigned ke node "Send Auto Reply"
- [ ] Warning "Credentials not set" hilang
- [ ] Workflow di-activate (toggle hijau)
- [ ] Test workflow dengan real message
- [ ] Bot berhasil auto-reply

---

## 📚 Related Docs

- **N8N_WORKFLOW_SETUP.md** - Panduan lengkap workflow setup
- **INSTALLATION_GUIDE.md** - Installation & configuration
- **MESSAGE_HANDLER_FIXES.md** - Issues #4 & #5 fixes

---

**Created**: 2025-12-18
**Issue**: Header Auth credential not set
**Node**: Send Auto Reply (HTTP Request)
**Required**: API Key from `.env` file
