# n8n Workflow Setup - Emergency Response Bot

## 📋 Persiapan

### 1. Create Database Table

Jalankan SQL ini untuk membuat table emergency_reports:

```bash
cd ~/neonize-emergency

# Copy SQL file ke container postgres
docker cp create_emergency_table.sql emergency_postgres:/tmp/

# Execute SQL
docker exec -it emergency_postgres psql -U emergency -d emergency_db -f /tmp/create_emergency_table.sql
```

**Atau manual via psql:**

```bash
docker exec -it emergency_postgres psql -U emergency -d emergency_db
```

Lalu copy-paste isi file `create_emergency_table.sql` dan jalankan.

---

## 🚀 Import Workflow ke n8n

### Langkah 1: Download Workflow File

Di server:

```bash
cd ~/neonize-emergency

# File sudah ada di: n8n_workflows/emergency_response_workflow.json
# Atau download lagi jika perlu:
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/n8n_workflows/emergency_response_workflow.json -o n8n_workflows/emergency_response_workflow.json
```

### Langkah 2: Import via n8n Web UI

1. **Buka n8n** di browser: `http://IP-SERVER:5678`

2. **Login** dengan credentials dari `credentials.txt`

3. **Import Workflow:**
   - Klik menu **"..."** (3 titik) di kanan atas
   - Pilih **"Import from file..."**
   - Atau klik **"Workflows"** di sidebar → **"Import from File"**

4. **Upload File:**
   - Klik **"Select file"** atau drag & drop
   - Pilih file: `emergency_response_workflow.json`
   - Klik **"Import"**

### Langkah 3: Setup Database Credentials

Workflow membutuhkan koneksi ke PostgreSQL:

1. **Di n8n**, klik **"Credentials"** di sidebar kiri

2. **Add New Credential:**
   - Klik **"+ Add Credential"**
   - Cari dan pilih **"Postgres"**

3. **Fill Credentials:**
   - **Name**: `Emergency DB`
   - **Host**: `postgres`
   - **Database**: `emergency_db`
   - **User**: `emergency`
   - **Password**: (lihat di `.env` file, variable `POSTGRES_PASSWORD`)
   - **Port**: `5432`
   - **SSL**: `disable`

4. **Test Connection:**
   - Klik **"Test"** untuk verify koneksi
   - Harus muncul: ✅ Connection tested successfully

5. **Save** credential

### Langkah 4: Update Node Postgres

Kembali ke workflow "Emergency Response Bot":

1. **Klik node "Save Emergency Report"** (node Postgres)

2. **Di panel kanan**, section **Credentials**:
   - Pilih credential: **"Emergency DB"** yang baru dibuat

3. **Save** workflow

### Langkah 5: Activate Workflow

1. **Di kanan atas workflow**, ada toggle **"Inactive"**

2. **Klik toggle** untuk mengaktifkan → Berubah jadi **"Active"** (hijau)

3. **Webhook URL** sekarang aktif di:
   ```
   http://n8n:5678/webhook/emergency
   ```

---

## ✅ Test Workflow

### Test 1: Kirim Pesan ke Bot

Kirim chat ke WhatsApp bot:

```
Ada banjir besar di daerah saya, air sudah setinggi 1 meter!
```

**Yang seharusnya terjadi:**

1. ✅ n8n menerima webhook dari bot
2. ✅ Message diproses dan di-filter (emergency keywords detected)
3. ✅ Data disimpan ke database
4. ✅ Bot auto-reply dengan konfirmasi laporan

**Bot akan balas:**

```
🌊 *LAPORAN DITERIMA*

ID Laporan: RPT-1734567890123
Jenis: FLOOD
Tingkat: ⭐⭐⭐⭐ (4/5)
Waktu: 17/12/2025 18:30:45

✅ Tim emergency response telah menerima laporan Anda.
📞 Kami akan segera menghubungi untuk verifikasi.

Tetap tenang dan ikuti instruksi petugas!
```

### Test 2: Check n8n Executions

1. **Di n8n**, klik **"Executions"** di sidebar

2. **Lihat list executions** → Harus ada entry baru

3. **Klik execution** untuk lihat detail flow

4. **Check setiap node** → Semua harus hijau (success)

### Test 3: Verify Database

```bash
docker exec -it emergency_postgres psql -U emergency -d emergency_db -c "SELECT * FROM emergency_reports ORDER BY created_at DESC LIMIT 5;"
```

**Harus muncul data laporan yang baru masuk.**

---

## 📊 Workflow Explanation

Workflow ini memiliki 8 nodes:

### 1. **Webhook Emergency** (Trigger)
- Menerima POST request dari neonize bot
- Path: `/webhook/emergency`
- Method: POST

### 2. **Switch Event Type**
- Route event berdasarkan `event_type`
- Output 1: `message_received` → Process message
- Output 2: `bot_connected` → Log status

### 3. **Process Message** (Code Node)
- Extract text, sender, timestamp
- Deteksi emergency keywords
- Classify disaster type (flood, earthquake, fire, etc.)
- Estimate severity (1-5)

### 4. **Filter Emergency Only**
- Hanya lewatkan message yang mengandung keyword emergency
- Message biasa di-skip (tidak disimpan)

### 5. **Save Emergency Report** (Postgres)
- Simpan ke table `emergency_reports`
- Status: `pending` (waiting verification)

### 6. **Generate Auto Reply** (Code Node)
- Buat message konfirmasi dengan:
  - Report ID unik
  - Emoji sesuai disaster type
  - Severity rating
  - Timestamp

### 7. **Send Auto Reply** (HTTP Request)
- Kirim auto-reply via neonize API
- Endpoint: `http://emergency_neonize:8000/send-message`
- Dengan API Key authentication

### 8. **Log Bot Status** (Code Node)
- Log when bot connected/disconnected
- Untuk monitoring

---

## 🔧 Customization

### Tambah Emergency Keyword

Edit node **"Process Message"**, cari baris:

```javascript
const emergencyKeywords = [
  'banjir', 'gempa', 'kebakaran', 'longsor', 'tsunami',
  'darurat', 'emergency', 'tolong', 'bahaya'
];
```

Tambahkan keyword baru sesuai kebutuhan.

### Ubah Auto Reply Template

Edit node **"Generate Auto Reply"**, cari variable `reply`:

```javascript
const reply = `${emoji} *LAPORAN DITERIMA*\n\n` +
  `ID Laporan: ${reportId}\n` +
  // ... customize message di sini
```

### Tambah Node Baru

Contoh tambahan yang bisa ditambahkan:

1. **Email Notification** → Kirim email ke tim
2. **Slack/Discord Alert** → Notifikasi ke channel
3. **Google Maps API** → Extract lokasi dari koordinat
4. **Twilio SMS** → SMS ke petugas jaga
5. **HTTP Request** → Trigger sistem eksternal

---

## 🐛 Troubleshooting

### Error: "Workflow could not be activated"

**Penyebab:** Webhook path sudah dipakai workflow lain

**Solusi:**
1. Deactivate workflow lain yang pakai path `/emergency`
2. Atau ganti path di node Webhook

### Error: "Could not connect to database"

**Penyebab:** Credentials salah atau database tidak accessible

**Solusi:**
1. Check credentials: Host harus `postgres` (bukan localhost)
2. Test connection di Credentials menu
3. Verify database running: `docker ps | grep postgres`

### Error: "Authentication required"

**Penyebab:** API Key tidak match

**Solusi:**
Edit node "Send Auto Reply", pastikan header:
```
X-Api-Key: {{ $env.API_KEY }}
```

Match dengan value di `.env` file.

### Bot Tidak Auto Reply

**Check:**

1. **Workflow Active?**
   - Toggle harus hijau

2. **Execution Success?**
   - Check di menu Executions
   - Lihat detail error jika ada

3. **API Endpoint Correct?**
   - URL: `http://emergency_neonize:8000/send-message`
   - Bukan `localhost`

4. **Logs:**
```bash
docker logs emergency_neonize --tail 50
docker logs emergency_n8n --tail 50
```

---

## 📊 Monitoring

### Check Executions

n8n menyimpan semua workflow executions:

- **Success** → Hijau
- **Error** → Merah
- **Waiting** → Kuning

### Database Query

```sql
-- Total laporan hari ini
SELECT COUNT(*)
FROM emergency_reports
WHERE created_at >= CURRENT_DATE;

-- Laporan by disaster type
SELECT disaster_type, COUNT(*)
FROM emergency_reports
GROUP BY disaster_type
ORDER BY COUNT(*) DESC;

-- Laporan severity tinggi
SELECT *
FROM emergency_reports
WHERE severity >= 4
ORDER BY created_at DESC;

-- Laporan pending
SELECT *
FROM emergency_reports
WHERE status = 'pending'
ORDER BY severity DESC, created_at DESC;
```

---

## 🎯 Next Steps

Setelah workflow berjalan:

1. **Setup Notifikasi Tim**
   - Tambah node untuk email/SMS/Slack
   - Trigger saat ada laporan severity tinggi

2. **Dashboard Monitoring**
   - Gunakan Grafana (already installed)
   - Visualize data dari `emergency_reports`

3. **Auto Assignment**
   - Logic untuk assign laporan ke petugas
   - Berdasarkan lokasi / disaster type

4. **Follow-up Workflow**
   - Kirim update ke pelapor
   - Status tracking

5. **Integration Eksternal**
   - BMKG API untuk data cuaca
   - Google Maps untuk geocoding
   - Government emergency systems

---

## 📚 Resources

- **n8n Documentation**: https://docs.n8n.io
- **Workflow Examples**: https://n8n.io/workflows
- **Community Forum**: https://community.n8n.io

---

**Created**: 2025-12-17
**Version**: 1.0
**Status**: Production Ready ✅
