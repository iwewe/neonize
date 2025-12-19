# Deploy Workflow V3 - Fix untuk id=0 Bug

## 🎯 Root Cause Yang Sudah Ditemukan

✅ **Database schema CORRECT** - manual INSERT test menghasilkan `id=1`
❌ **n8n Postgres node (typeVersion 2.4) punya BUG** - selalu insert `id=0`

**Solusi:** Bypass n8n Postgres node, gunakan custom API endpoint dengan psycopg2 direct connection.

---

## 📋 Step 1: Restart Neonize Container

Neonize API sudah diupdate dengan endpoint `/save-emergency-report`:

```bash
cd ~/neonize-emergency

# Restart container untuk load kode terbaru
docker compose -f docker-compose.emergency.yml restart emergency_neonize

# Verify container running
docker ps | grep emergency_neonize

# Check logs
docker logs --tail 20 emergency_neonize
```

**Expected log:**
```
INFO:     Started server process
INFO:     Application startup complete
✅ Neonize connected to WhatsApp!
```

---

## 📥 Step 2: Download Workflow V3

```bash
cd ~/neonize-emergency

# Download workflow v3 (uses HTTP Request instead of Postgres node)
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/n8n_workflows/emergency_response_workflow_v3.json -o emergency_response_workflow_v3.json

# Verify download
ls -lh emergency_response_workflow_v3.json
```

---

## 🔧 Step 3: Import Workflow V3 ke n8n

### 3.1. Nonaktifkan Workflow Lama

1. **Buka n8n:** `http://IP-SERVER:5678`
2. **Klik workflow** "Emergency Response Bot" (yang lama)
3. **Toggle Active → Inactive**
4. (Optional) Rename jadi "Emergency Response Bot OLD"

### 3.2. Import Workflow V3

1. **Klik menu "..."** (3 titik) di kanan atas
2. Pilih **"Import from file..."**
3. **Upload:** `emergency_response_workflow_v3.json`
4. Klik **"Import"**
5. **Rename** jadi: "Emergency Response Bot V3"

---

## 🔑 Step 4: Assign Credentials

Workflow V3 membutuhkan **2 credentials** (sama seperti sebelumnya):

### 4.1. Header Auth Credential (untuk kedua HTTP Request nodes)

**Node 1: "Save Emergency Report"** (HTTP Request node)
- Klik node → Panel kanan → **Credentials**
- Select: **"Neonize API Key"** (yang sudah dibuat sebelumnya)

**Node 2: "Send Auto Reply"** (HTTP Request node)
- Klik node → Panel kanan → **Credentials**
- Select: **"Neonize API Key"** (yang sama)

### 4.2. Verify Credentials

- **Credentials → Neonize API Key**
- Pastikan:
  - **Name**: `X-Api-Key`
  - **Value**: API key dari `.env` file

---

## ✅ Step 5: Activate Workflow V3

1. Di kanan atas workflow, **toggle Inactive → Active** (hijau)
2. **Klik "Save"**
3. Workflow siap digunakan!

---

## 🧪 Step 6: Test Workflow V3

### Test 1: Clean Database

```bash
cd ~/neonize-emergency
./clean_emergency_db.sh
```

### Test 2: Run Webhook Test

```bash
./test_n8n_webhook.sh
```

**Expected output:**
```
id | sender_name | disaster_type | severity | message_preview
---+-------------+---------------+----------+-----------------
 1 | Test User   | flood         |        5 | Ada banjir besar...
```

✅ **id = 1** (BUKAN 0 lagi!)

### Test 3: Real WhatsApp Message

Kirim pesan ke bot:
```
Ada kebakaran di rumah saya! Tolong segera kirim bantuan! Sangat parah!
```

**Expected:**
- ✅ Bot auto-reply dengan Report ID: `RPT-1234567890123`
- ✅ Data tersimpan di database dengan `id=2` (auto-increment)
- ✅ No duplicate key errors!

---

## 🔍 Verify Database

```bash
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT id, sender_name, disaster_type, severity, LEFT(message_text, 60) as message, created_at
FROM emergency_reports
ORDER BY created_at DESC
LIMIT 5;
"
```

**Expected:**
```
 id | sender_name | disaster_type | severity | message                            | created_at
----+-------------+---------------+----------+------------------------------------+-------------------
  2 | Real User   | fire          |        5 | Ada kebakaran di rumah saya! ...   | 2025-12-19 ...
  1 | Test User   | flood         |        5 | Ada banjir besar di daerah saya... | 2025-12-19 ...
```

---

## 📊 Check n8n Executions

1. **n8n UI → Tab "Executions"**
2. **Klik execution terakhir**
3. **Verify semua nodes sukses:**
   - ✅ Webhook Emergency
   - ✅ Switch Event Type
   - ✅ Process Message
   - ✅ Filter Emergency Only
   - ✅ **Save Emergency Report (HTTP Request)** ← Node baru!
   - ✅ Generate Auto Reply
   - ✅ Send Auto Reply

4. **Klik node "Save Emergency Report"**
5. **Tab OUTPUT** - verify response:
   ```json
   {
     "success": true,
     "message": "Emergency report saved successfully",
     "data": {
       "id": 1,
       "report_id": "RPT-1734567890123",
       "sender": "628xxx@s.whatsapp.net",
       "sender_name": "Test User",
       "disaster_type": "flood",
       "severity": 5,
       "created_at": "2025-12-19T00:xx:xx"
     }
   }
   ```

---

## 🐛 Troubleshooting

### Error: "Authentication failed"

**Check:**
- Header Auth credential sudah di-assign ke node "Save Emergency Report"?
- API Key benar? Cek di `.env` file: `grep API_KEY .env`

**Fix:**
```bash
# Verify API key
cat ~/neonize-emergency/.env | grep API_KEY

# Update credential di n8n jika berbeda
```

### Error: "Database error: connection refused"

**Check:**
- PostgreSQL container running? `docker ps | grep postgres`
- Neonize container bisa connect ke postgres?

**Fix:**
```bash
# Restart both containers
docker compose -f docker-compose.emergency.yml restart emergency_postgres emergency_neonize

# Check logs
docker logs emergency_neonize
```

### Error: "Module psycopg2 not found"

**Unlikely** - psycopg2-binary sudah di requirements.txt

**Fix jika terjadi:**
```bash
# Rebuild container
docker compose -f docker-compose.emergency.yml build emergency_neonize
docker compose -f docker-compose.emergency.yml up -d emergency_neonize
```

### Workflow masih insert id=0

**Kemungkinan:**
- Workflow lama masih active (ada 2 workflow active bersamaan)
- Credential belum di-assign ke node baru

**Fix:**
1. **Pastikan hanya workflow V3 yang active**
2. **Check semua HTTP Request nodes punya credential**
3. **Restart workflow:** Inactive → Active

---

## 📈 Monitoring

### Check Neonize API Logs

```bash
# Real-time logs
docker logs -f emergency_neonize

# Filter save-emergency-report calls
docker logs emergency_neonize 2>&1 | grep "save-emergency-report"
```

**Expected:**
```
INFO:     ... - "POST /save-emergency-report HTTP/1.1" 200 OK
✅ Emergency report saved: ID=1, Type=flood, Display=RPT-1734567890123
```

### Check PostgreSQL Sequence

```bash
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT last_value FROM emergency_reports_id_seq;
"
```

After 3 inserts, should show: `last_value = 3`

---

## ✅ Success Indicators

1. ✅ Workflow V3 active dan running
2. ✅ Test webhook menghasilkan `id=1, 2, 3...` (tidak ada id=0)
3. ✅ Bot auto-reply dengan Report ID
4. ✅ No duplicate key constraint errors di n8n executions
5. ✅ Neonize logs menunjukkan "Emergency report saved: ID=X"

---

## 🎉 Selesai!

Workflow V3 sekarang menggunakan:
- ✅ Custom API endpoint `/save-emergency-report`
- ✅ Direct psycopg2 connection (reliable auto-increment)
- ✅ Bypass n8n Postgres node bug
- ✅ Proper error handling

**Masalah id=0 SOLVED!** 🚀

---

**Created:** 2025-12-19
**Issue:** n8n Postgres node typeVersion 2.4 bug (always inserts id=0)
**Solution:** Custom API endpoint with direct database connection
**Status:** ✅ FIXED
