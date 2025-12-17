# Analisis Neonize untuk Chatbot Emergency Response

## Daftar Isi
- [Ringkasan Eksekutif](#ringkasan-eksekutif)
- [1. Skenario Implementasi](#1-skenario-implementasi)
- [2. Integrasi dengan n8n](#2-integrasi-dengan-n8n)
- [3. Arsitektur Teknis](#3-arsitektur-teknis)
- [4. Implementasi Best Practices](#4-implementasi-best-practices)
- [5. Roadmap Implementasi](#5-roadmap-implementasi)

---

## Ringkasan Eksekutif

**Neonize** adalah library Python untuk automasi WhatsApp yang dibangun di atas Whatsmeow (Go). Library ini sangat cocok untuk **chatbot kebencanaan** karena:

✅ **Real-time messaging** - Komunikasi instan dua arah
✅ **Media support lengkap** - Kirim/terima gambar, video, lokasi, dokumen
✅ **Event-driven architecture** - Respons cepat terhadap kejadian
✅ **Multi-session support** - Kelola banyak akun/wilayah sekaligus
✅ **Integrasi mudah** - API Python yang clean dan dokumentasi lengkap
✅ **Scalable** - Backend Go untuk performa tinggi

---

## 1. Skenario Implementasi

### 1.1 Skenario Pelaporan Bencana Real-Time

**Use Case**: Warga melaporkan bencana melalui WhatsApp

**Fitur Neonize yang Digunakan**:
- `MessageEv` - Menerima laporan teks
- `download_any()` - Download foto/video bukti kejadian
- `send_message()` - Konfirmasi penerimaan laporan
- `build_poll_vote_creation()` - Quick response untuk tipe bencana

**Flow Implementasi**:
```python
from neonize.client import NewClient
from neonize.events import MessageEv
from neonize.utils import build_jid
import json
from datetime import datetime

client = NewClient("emergency_bot")

# Database sederhana untuk tracking laporan
laporan_db = {}

@client.event
def on_message(client: NewClient, event: MessageEv):
    """Handle laporan masuk dari warga"""

    # Abaikan pesan dari bot sendiri
    if event.Info.MessageSource.IsFromMe:
        return

    sender = event.Info.MessageSource.Sender
    chat = event.Info.MessageSource.Chat
    msg = event.Message

    # 1. LAPORAN TEKS
    if msg.conversation:
        text = msg.conversation.lower()

        # Deteksi keyword bencana
        if any(word in text for word in ['banjir', 'kebakaran', 'gempa', 'longsor', 'angin']):
            # Simpan laporan
            report_id = f"RPT{datetime.now().strftime('%Y%m%d%H%M%S')}"
            laporan_db[report_id] = {
                'reporter': sender,
                'timestamp': datetime.now().isoformat(),
                'message': msg.conversation,
                'location': None,
                'media': [],
                'status': 'PENDING'
            }

            # Kirim konfirmasi
            response = f"""✅ *LAPORAN DITERIMA*
ID: {report_id}
Waktu: {datetime.now().strftime('%H:%M:%S')}

Terima kasih atas laporannya. Tim sedang memverifikasi.

📍 Mohon kirim lokasi Anda (Share Location)
📸 Kirim foto/video jika tersedia

Status akan diupdate segera."""

            client.send_message(chat, text=response)

            # Kirim quick poll untuk klasifikasi tingkat urgensi
            poll = client.build_poll_vote_creation(
                name="Tingkat Urgensi?",
                options=["🔴 SANGAT DARURAT", "🟡 MENDESAK", "🟢 TERKENDALI"],
                selectable_options_count=1
            )
            client.send_message(chat, poll_creation=poll)

    # 2. LAPORAN LOKASI
    elif msg.locationMessage:
        lat = msg.locationMessage.degreesLatitude
        lon = msg.locationMessage.degreesLongitude

        # Update laporan terakhir dari user ini
        for report_id, data in laporan_db.items():
            if data['reporter'] == sender and data['location'] is None:
                data['location'] = {'lat': lat, 'lon': lon}

                response = f"""📍 *LOKASI TERSIMPAN*
Koordinat: {lat}, {lon}
Google Maps: https://maps.google.com/?q={lat},{lon}

Tim terdekat akan segera dihubungi."""

                client.send_message(chat, text=response)

                # TRIGGER: Kirim ke sistem dispatch
                # notify_emergency_team(report_id, lat, lon)
                break

    # 3. LAPORAN MEDIA (FOTO/VIDEO BUKTI)
    elif msg.imageMessage or msg.videoMessage:
        # Download media untuk analisis
        media_data = client.download_any(msg)

        # Simpan media
        for report_id, data in laporan_db.items():
            if data['reporter'] == sender:
                filename = f"{report_id}_{len(data['media'])}.jpg"
                with open(f"/tmp/{filename}", 'wb') as f:
                    f.write(media_data)

                data['media'].append(filename)

                client.send_message(
                    chat,
                    text="✅ Foto/video diterima. Terima kasih atas dokumentasinya!"
                )
                break

@client.event
def on_connected(client: NewClient, _):
    print("✅ Emergency Bot Connected!")

    # Broadcast status online ke group terdaftar
    # emergency_groups = ["120363xxxxx@g.us"]  # Group ID
    # for group in emergency_groups:
    #     client.send_message(group, text="🟢 Emergency Bot is ONLINE")

if __name__ == "__main__":
    client.connect()
```

**Output yang Diharapkan**:
- ✅ Auto-response dalam <2 detik
- ✅ Tracking laporan dengan ID unik
- ✅ Geo-tagging otomatis
- ✅ Dokumentasi visual tersimpan

---

### 1.2 Skenario Broadcast Alert & Peringatan Dini

**Use Case**: Kirim peringatan massal ke wilayah terdampak

**Fitur Neonize yang Digunakan**:
- `get_all_contacts()` - Daftar penerima
- `send_message()` - Broadcast pesan
- `send_image()` - Kirim peta evakuasi
- `send_location()` - Lokasi shelter/posko

**Flow Implementasi**:
```python
from neonize.client import NewClient
from neonize.utils import build_jid
from datetime import datetime
import asyncio

class EmergencyBroadcaster:
    def __init__(self, session_name="broadcaster"):
        self.client = NewClient(session_name)

        # Database kontak darurat per wilayah
        self.emergency_contacts = {
            'jakarta_utara': ['628123456789@s.whatsapp.net'],
            'jakarta_barat': ['628987654321@s.whatsapp.net'],
            # dst...
        }

    def send_alert(self, region, alert_type, message, media_path=None):
        """
        Kirim alert ke wilayah tertentu

        Args:
            region: Wilayah target (key dari emergency_contacts)
            alert_type: TSUNAMI, BANJIR, GEMPA, KEBAKARAN
            message: Isi peringatan
            media_path: Path ke gambar/peta (optional)
        """
        contacts = self.emergency_contacts.get(region, [])

        # Format pesan
        alert_header = {
            'TSUNAMI': '🌊 *PERINGATAN TSUNAMI*',
            'BANJIR': '💧 *PERINGATAN BANJIR*',
            'GEMPA': '🌍 *PERINGATAN GEMPA*',
            'KEBAKARAN': '🔥 *PERINGATAN KEBAKARAN*'
        }

        full_message = f"""{alert_header.get(alert_type, '⚠️ PERINGATAN')}

{message}

Waktu: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}
Wilayah: {region.upper().replace('_', ' ')}

⚠️ SEGERA LAKUKAN:
1. Tetap tenang
2. Ikuti instruksi petugas
3. Hubungi 112 jika darurat

#EmergencyAlert #BNPB"""

        # Kirim ke semua kontak di wilayah
        for contact in contacts:
            try:
                # Kirim pesan teks
                self.client.send_message(contact, text=full_message)

                # Kirim media jika ada (peta evakuasi, dll)
                if media_path:
                    with open(media_path, 'rb') as f:
                        self.client.send_image(
                            contact,
                            image=f.read(),
                            caption="Peta jalur evakuasi terdekat"
                        )

                print(f"✅ Alert sent to {contact}")

            except Exception as e:
                print(f"❌ Failed to send to {contact}: {e}")

    def broadcast_to_groups(self, group_jids, message):
        """Broadcast ke group-group tanggap darurat"""
        for group in group_jids:
            self.client.send_message(group, text=message)

    def send_shelter_location(self, contacts, lat, lon, name):
        """Kirim lokasi posko/shelter terdekat"""
        for contact in contacts:
            # Kirim lokasi
            location_msg = self.client.build_location_message(
                latitude=lat,
                longitude=lon,
                name=name,
                address=f"Posko darurat {name}"
            )
            self.client.send_message(contact, location=location_msg)

# Contoh penggunaan
if __name__ == "__main__":
    broadcaster = EmergencyBroadcaster()
    broadcaster.client.connect()

    # Simulasi: Alert banjir di Jakarta Utara
    broadcaster.send_alert(
        region='jakarta_utara',
        alert_type='BANJIR',
        message="""Air sungai Ciliwung meluap setinggi 1.5 meter.

EVAKUASI SEGERA untuk warga:
- Kelurahan Ancol
- Kelurahan Sunter Agung
- Kelurahan Pademangan Timur

Posko: GOR Sunter (Maps akan dikirim)""",
        media_path='maps/evakuasi_jakut.jpg'
    )

    # Kirim lokasi posko
    broadcaster.send_shelter_location(
        contacts=broadcaster.emergency_contacts['jakarta_utara'],
        lat=-6.1396,
        lon=106.8679,
        name="GOR Sunter"
    )
```

**Keunggulan**:
- ✅ Targeted broadcast per wilayah
- ✅ Multi-format: Text + Image + Location
- ✅ Timestamps akurat
- ✅ Scalable untuk banyak kontak

---

### 1.3 Skenario Koordinasi Tim Lapangan

**Use Case**: Koordinasi relawan/petugas di lapangan via group

**Fitur Neonize yang Digunakan**:
- `create_group()` - Buat group task force
- `update_group_participants()` - Tambah/hapus anggota
- `GroupInfoEv` - Monitor perubahan group
- `send_poll_creation()` - Polling ketersediaan tim

**Flow Implementasi**:
```python
from neonize.client import NewClient
from neonize.events import MessageEv, GroupInfoEv
from neonize.utils import build_jid

class FieldCoordinator:
    def __init__(self):
        self.client = NewClient("field_coordinator")
        self.active_teams = {}  # {group_jid: team_info}

        @self.client.event
        def on_message(client, event: MessageEv):
            self._handle_field_message(event)

        @self.client.event
        def on_group_info(client, event: GroupInfoEv):
            self._handle_group_update(event)

    def create_emergency_team(self, team_name, members, mission):
        """
        Buat group koordinasi darurat

        Args:
            team_name: Nama tim (e.g., "Tim Evakuasi Sektor A")
            members: List phone numbers (e.g., ['628123456789'])
            mission: Deskripsi misi
        """
        # Convert ke JID
        member_jids = [build_jid(phone) for phone in members]

        # Buat group
        group_info = self.client.create_group(
            name=f"🚨 {team_name}",
            participants=member_jids
        )

        group_jid = group_info.JID

        # Set deskripsi group
        self.client.set_group_topic(
            jid=group_jid,
            topic=f"""MISI: {mission}

📋 PROTOKOL:
- Report status setiap 30 menit
- Gunakan /sitrep untuk situation report
- Emergency: Tag @koordinator

Dibuat: {datetime.now().strftime('%d/%m/%Y %H:%M')}"""
        )

        # Kirim welcome message
        welcome = f"""✅ *TIM DIBENTUK*

👥 Anggota: {len(members)} orang
🎯 Misi: {mission}

⚠️ COMMAND CEPAT:
- Ketik "/help" untuk bantuan
- Ketik "/sitrep" untuk laporan situasi
- Ketik "/sos" untuk darurat

📍 Share lokasi real-time saat operasi
📸 Dokumentasikan kondisi lapangan

Stay safe! 🙏"""

        self.client.send_message(group_jid, text=welcome)

        # Polling ketersediaan
        availability_poll = self.client.build_poll_vote_creation(
            name="Konfirmasi Ketersediaan",
            options=["✅ Siap", "⏰ Perlu 15 menit", "❌ Tidak tersedia"],
            selectable_options_count=1
        )
        self.client.send_message(group_jid, poll_creation=availability_poll)

        # Simpan info tim
        self.active_teams[group_jid] = {
            'name': team_name,
            'mission': mission,
            'created': datetime.now(),
            'members': member_jids,
            'status': 'ACTIVE'
        }

        return group_jid

    def _handle_field_message(self, event: MessageEv):
        """Handle pesan dari group lapangan"""
        if not event.Info.MessageSource.IsGroup:
            return

        chat = event.Info.MessageSource.Chat
        sender = event.Info.MessageSource.Sender
        msg = event.Message

        # Command handler
        if msg.conversation:
            text = msg.conversation.strip()

            # /sitrep - Situation Report
            if text.lower() == '/sitrep':
                sitrep_template = """📊 *SITUATION REPORT*

Waktu: [HH:MM]
Lokasi: [Nama Lokasi]
Status: [AMAN/BERBAHAYA/TERKENDALI]

👥 Korban:
- Terluka: [jumlah]
- Meninggal: [jumlah]
- Hilang: [jumlah]

📍 Kondisi:
[Deskripsi singkat]

🆘 Kebutuhan:
[Logistik yang diperlukan]

Pelapor: @{sender.split('@')[0]}"""

                self.client.send_message(chat, text=sitrep_template)

            # /sos - Emergency
            elif text.lower() == '/sos':
                # Forward ke command center
                self.client.send_message(
                    chat,
                    text=f"🆘 *SOS DITERIMA* dari @{sender.split('@')[0]}\n\nKoordinator akan segera merespons!"
                )
                # TODO: Notify command center

            # /help
            elif text.lower() == '/help':
                help_text = """📱 *COMMAND AVAILABLE*

/sitrep - Template laporan situasi
/sos - Minta bantuan darurat
/help - Tampilkan ini

Selain command, gunakan:
- 📍 Share location untuk tracking
- 📸 Kirim foto kondisi lapangan
- 🎤 Voice note untuk laporan cepat"""

                self.client.send_message(chat, text=help_text)

        # Track lokasi tim
        elif msg.locationMessage:
            lat = msg.locationMessage.degreesLatitude
            lon = msg.locationMessage.degreesLongitude

            # Simpan ke database tracking
            # save_team_location(sender, lat, lon, datetime.now())

            self.client.send_message(
                chat,
                text=f"✅ Lokasi @{sender.split('@')[0]} tersimpan: {lat}, {lon}"
            )

    def _handle_group_update(self, event: GroupInfoEv):
        """Monitor perubahan group (anggota keluar/masuk, dll)"""
        # Log group changes untuk audit trail
        pass

    def send_team_update(self, group_jid, update_message):
        """Kirim update ke tim lapangan"""
        formatted = f"""📢 *UPDATE FROM COMMAND*

{update_message}

Waktu: {datetime.now().strftime('%H:%M:%S')}"""

        self.client.send_message(group_jid, text=formatted)

    def dissolve_team(self, group_jid):
        """Bubarkan tim setelah misi selesai"""
        if group_jid in self.active_teams:
            # Kirim closing message
            self.client.send_message(
                group_jid,
                text="""✅ *MISI SELESAI*

Terima kasih atas dedikasi tim!
Group akan tetap ada untuk dokumentasi.

Stay safe! 🙏"""
            )

            # Update status
            self.active_teams[group_jid]['status'] = 'COMPLETED'
            self.active_teams[group_jid]['completed'] = datetime.now()

            # Leave group (optional)
            # self.client.leave_group(group_jid)

# Contoh penggunaan
if __name__ == "__main__":
    coordinator = FieldCoordinator()
    coordinator.client.connect()

    # Buat tim evakuasi
    team_jid = coordinator.create_emergency_team(
        team_name="Tim Evakuasi Sektor A",
        members=['628123456789', '628987654321'],
        mission="Evakuasi warga RW 05 terdampak banjir"
    )

    # Kirim update ke tim
    coordinator.send_team_update(
        team_jid,
        "Air mulai surut. Lanjutkan evakuasi sektor utara."
    )
```

**Benefit**:
- ✅ Real-time coordination
- ✅ Built-in command system
- ✅ Location tracking
- ✅ Audit trail lengkap

---

### 1.4 Skenario Helpdesk & Information Center

**Use Case**: Bot menjawab pertanyaan umum seputar bencana

**Fitur Neonize yang Digunakan**:
- `MessageEv` - Deteksi pertanyaan
- `build_reply_message()` - Quote message
- `send_contact()` - Kirim kontak hotline
- Interactive messages untuk FAQ

**Flow Implementasi**:
```python
from neonize.client import NewClient
from neonize.events import MessageEv
import re

class EmergencyHelpdesk:
    def __init__(self):
        self.client = NewClient("helpdesk_bot")

        # Knowledge base FAQ
        self.faq = {
            'shelter': """📍 *LOKASI SHELTER TERDEKAT*

1. GOR Sunter - Jl. Sunter Permai
2. Balai Warga RW 08 - Jl. Ancol
3. Gereja Santo Bellarminus - Sunter

Google Maps: [link akan dikirim]""",

            'logistik': """📦 *KEBUTUHAN LOGISTIK*

Saat ini dibutuhkan:
- Air mineral (prioritas tinggi)
- Makanan instan
- Selimut & kasur lipat
- Obat-obatan dasar

Titik donasi:
- Posko GOR Sunter (24 jam)
- Kelurahan Sunter Agung""",

            'evakuasi': """🚨 *PANDUAN EVAKUASI*

SEGERA jika:
- Air mencapai lutut orang dewasa
- Arus deras
- Peringatan dari petugas

BAWA:
✓ Dokumen penting (KTP, KK, Ijazah)
✓ Obat-obatan rutin
✓ Powerbank & charger
✓ Uang tunai secukupnya

JANGAN:
✗ Membawa barang berat
✗ Kembali ke rumah tanpa izin
✗ Panik""",

            'hotline': """☎️ *HOTLINE DARURAT*

🚨 Darurat Umum: 112
🚒 Pemadam: 113
🚑 Ambulans: 118
👮 Polisi: 110

🏛️ BPBD Jakarta: 021-xxxx
⛑️ PMI: 021-yyyy

24/7 Available"""
        }

    def setup_handlers(self):
        @self.client.event
        def on_message(client, event: MessageEv):
            self._handle_helpdesk_message(event)

    def _handle_helpdesk_message(self, event: MessageEv):
        """Handle pertanyaan dari user"""
        # Skip pesan dari bot sendiri & group
        if event.Info.MessageSource.IsFromMe or event.Info.MessageSource.IsGroup:
            return

        chat = event.Info.MessageSource.Chat
        sender = event.Info.MessageSource.Sender
        msg = event.Message

        if not msg.conversation:
            return

        text = msg.conversation.lower()

        # Deteksi intent dengan keyword matching
        response = None

        if any(word in text for word in ['shelter', 'posko', 'pengungsian', 'tempat']):
            response = self.faq['shelter']

            # Kirim juga lokasi
            # TODO: Kirim koordinat shelter terdekat

        elif any(word in text for word in ['logistik', 'donasi', 'bantuan', 'kebutuhan']):
            response = self.faq['logistik']

        elif any(word in text for word in ['evakuasi', 'mengungsi', 'cara']):
            response = self.faq['evakuasi']

        elif any(word in text for word in ['telepon', 'hotline', 'hubungi', 'kontak', 'nomor']):
            response = self.faq['hotline']

            # Kirim kontak cards
            self.client.send_contact(
                jid=chat,
                name="BPBD Jakarta",
                number="+62215551234"
            )

        # Greeting
        elif any(word in text for word in ['halo', 'hai', 'help', 'bantuan']):
            response = """👋 Halo! Saya bot informasi darurat.

Saya bisa bantu dengan:
📍 Lokasi shelter
📦 Info logistik & donasi
🚨 Panduan evakuasi
☎️ Hotline darurat

Ketik kata kunci atau pertanyaan Anda."""

        # Unknown query
        else:
            response = """Maaf, saya belum memahami pertanyaan Anda.

Coba tanyakan:
- "Dimana lokasi shelter?"
- "Apa yang dibutuhkan?"
- "Bagaimana cara evakuasi?"
- "Nomor hotline?"

Atau hubungi operator: /operator"""

        # Kirim response
        if response:
            # Reply to message
            reply = self.client.build_reply_message(
                message_id=event.Info.ID,
                chat=chat,
                text=response
            )
            self.client.send_message(chat, reply_message=reply)

    def send_menu(self, chat_jid):
        """Kirim interactive menu"""
        menu = """🤖 *EMERGENCY INFO BOT*

Pilih topik di bawah:

1️⃣ Lokasi Shelter
2️⃣ Kebutuhan Logistik
3️⃣ Panduan Evakuasi
4️⃣ Hotline Darurat
5️⃣ Bicara dengan Operator

Balas dengan nomor (1-5)"""

        self.client.send_message(chat_jid, text=menu)

# Contoh penggunaan
if __name__ == "__main__":
    helpdesk = EmergencyHelpdesk()
    helpdesk.setup_handlers()
    helpdesk.client.connect()
```

**Features**:
- ✅ 24/7 auto-response
- ✅ Keyword-based intent detection
- ✅ Multi-format response (text, location, contact)
- ✅ Escalation ke operator jika perlu

---

### 1.5 Skenario Monitoring & Analytics

**Use Case**: Dashboard real-time untuk situational awareness

**Fitur Neonize yang Digunakan**:
- `ReceiptEv` - Track delivery status
- `PresenceEv` - Monitor user online/offline
- Event logging untuk analytics

**Flow Implementasi**:
```python
from neonize.client import NewClient
from neonize.events import MessageEv, ReceiptEv, PresenceEv
from collections import defaultdict
from datetime import datetime
import json

class EmergencyMonitoring:
    def __init__(self):
        self.client = NewClient("monitoring")

        # Metrics storage
        self.metrics = {
            'messages_received': 0,
            'messages_sent': 0,
            'reports_count': 0,
            'alerts_sent': 0,
            'response_times': [],
            'active_users': set(),
            'message_delivery': defaultdict(int)  # delivered, read, failed
        }

        self.setup_monitoring()

    def setup_monitoring(self):
        @self.client.event
        def on_message(client, event: MessageEv):
            self._track_message(event)

        @self.client.event
        def on_receipt(client, event: ReceiptEv):
            self._track_delivery(event)

        @self.client.event
        def on_presence(client, event: PresenceEv):
            self._track_presence(event)

    def _track_message(self, event: MessageEv):
        """Track incoming messages"""
        self.metrics['messages_received'] += 1

        # Track active users
        sender = event.Info.MessageSource.Sender
        self.metrics['active_users'].add(sender)

        # Detect if it's a report
        if event.Message.conversation:
            text = event.Message.conversation.lower()
            if any(word in text for word in ['lapor', 'banjir', 'kebakaran', 'gempa']):
                self.metrics['reports_count'] += 1

        # Log untuk analytics
        self._log_event('message_received', {
            'timestamp': datetime.now().isoformat(),
            'sender': sender,
            'is_group': event.Info.MessageSource.IsGroup,
            'message_type': self._get_message_type(event.Message)
        })

    def _track_delivery(self, event: ReceiptEv):
        """Track message delivery status"""
        # ReceiptType: READ, PLAYED, DELIVERED
        receipt_type = event.Type

        if receipt_type == 'READ':
            self.metrics['message_delivery']['read'] += 1
        elif receipt_type == 'DELIVERED':
            self.metrics['message_delivery']['delivered'] += 1

        self._log_event('receipt', {
            'timestamp': datetime.now().isoformat(),
            'type': str(receipt_type),
            'message_ids': event.MessageIDs
        })

    def _track_presence(self, event: PresenceEv):
        """Track user presence (online/offline)"""
        self._log_event('presence', {
            'timestamp': datetime.now().isoformat(),
            'jid': event.JID,
            'is_available': event.IsAvailable
        })

    def _get_message_type(self, message):
        """Detect message type"""
        if message.conversation:
            return 'text'
        elif message.imageMessage:
            return 'image'
        elif message.videoMessage:
            return 'video'
        elif message.locationMessage:
            return 'location'
        elif message.documentMessage:
            return 'document'
        else:
            return 'other'

    def _log_event(self, event_type, data):
        """Log event ke file/database"""
        log_entry = {
            'event': event_type,
            'data': data
        }

        # Append ke log file
        with open('/tmp/emergency_bot_events.jsonl', 'a') as f:
            f.write(json.dumps(log_entry) + '\n')

    def get_dashboard_stats(self):
        """Generate dashboard statistics"""
        return {
            'total_messages_received': self.metrics['messages_received'],
            'total_reports': self.metrics['reports_count'],
            'total_alerts_sent': self.metrics['alerts_sent'],
            'unique_active_users': len(self.metrics['active_users']),
            'delivery_stats': dict(self.metrics['message_delivery']),
            'avg_response_time': sum(self.metrics['response_times']) / len(self.metrics['response_times'])
                                 if self.metrics['response_times'] else 0
        }

    def export_report(self, filepath='/tmp/emergency_report.json'):
        """Export full analytics report"""
        report = {
            'generated_at': datetime.now().isoformat(),
            'summary': self.get_dashboard_stats(),
            'raw_metrics': {
                'messages_received': self.metrics['messages_received'],
                'reports_count': self.metrics['reports_count'],
                'active_users_list': list(self.metrics['active_users'])
            }
        }

        with open(filepath, 'w') as f:
            json.dumps(report, f, indent=2)

        return filepath

# Contoh penggunaan
if __name__ == "__main__":
    monitor = EmergencyMonitoring()
    monitor.client.connect()

    # Setiap 5 menit, print stats
    import time
    while True:
        time.sleep(300)  # 5 menit
        stats = monitor.get_dashboard_stats()
        print(f"[{datetime.now()}] Stats: {stats}")
```

**Insights yang Didapat**:
- ✅ Total laporan masuk
- ✅ Response time rata-rata
- ✅ Delivery success rate
- ✅ Active users count
- ✅ Message type distribution

---

## 2. Integrasi dengan n8n

### 2.1 Arsitektur Integrasi

**n8n** adalah workflow automation tool yang dapat diintegrasikan dengan neonize melalui:

1. **HTTP Request Node** ← REST API dari neonize
2. **Webhook Node** ← Events dari neonize
3. **Python/Execute Node** ← Direct script execution

**Diagram Integrasi**:
```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  WhatsApp   │ ←──────→│   Neonize    │ ←──────→│     n8n     │
│   Users     │         │  Python Bot  │   HTTP  │  Workflows  │
└─────────────┘         └──────────────┘         └─────────────┘
                              │                        │
                              │                        │
                              ↓                        ↓
                        ┌──────────┐            ┌──────────┐
                        │ Database │            │ External │
                        │ (Events) │            │   APIs   │
                        └──────────┘            └──────────┘
```

---

### 2.2 Metode 1: REST API Bridge (Recommended)

**Implementasi**: Buat FastAPI server sebagai bridge antara neonize dan n8n

```python
from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from neonize.client import NewClient
from neonize.events import MessageEv
from neonize.utils import build_jid
import httpx
import asyncio
from typing import Optional

app = FastAPI(title="Neonize n8n Bridge")

# Neonize client (sync mode dengan threading)
neonize_client = None

# n8n webhook URL
N8N_WEBHOOK_URL = "https://your-n8n.com/webhook/emergency"

# Models
class SendMessageRequest(BaseModel):
    phone: str
    message: str
    media_url: Optional[str] = None
    media_type: Optional[str] = None  # image, video, document

class SendBroadcastRequest(BaseModel):
    phones: list[str]
    message: str

class CreateGroupRequest(BaseModel):
    name: str
    members: list[str]

# --- API ENDPOINTS ---

@app.post("/send-message")
async def send_message(request: SendMessageRequest):
    """
    n8n calls this to send WhatsApp message

    Example n8n HTTP Request Node:
    URL: http://localhost:8000/send-message
    Method: POST
    Body: {
        "phone": "628123456789",
        "message": "Alert: Banjir terdeteksi di wilayah Anda!"
    }
    """
    try:
        jid = build_jid(request.phone)

        # Send text
        neonize_client.send_message(jid, text=request.message)

        # Send media if provided
        if request.media_url:
            # Download media
            async with httpx.AsyncClient() as client:
                response = await client.get(request.media_url)
                media_data = response.content

            if request.media_type == 'image':
                neonize_client.send_image(jid, image=media_data)
            elif request.media_type == 'video':
                neonize_client.send_video(jid, video=media_data)
            elif request.media_type == 'document':
                neonize_client.send_document(jid, doc=media_data, filename='document.pdf')

        return {"status": "success", "phone": request.phone}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/send-broadcast")
async def send_broadcast(request: SendBroadcastRequest):
    """
    Broadcast to multiple numbers

    Example n8n usage:
    Loop over contact list and call this endpoint
    """
    results = []
    for phone in request.phones:
        try:
            jid = build_jid(phone)
            neonize_client.send_message(jid, text=request.message)
            results.append({"phone": phone, "status": "sent"})
        except Exception as e:
            results.append({"phone": phone, "status": "failed", "error": str(e)})

    return {"results": results}

@app.post("/create-group")
async def create_group(request: CreateGroupRequest):
    """
    Create WhatsApp group

    Example: Create emergency response team group
    """
    try:
        member_jids = [build_jid(phone) for phone in request.members]
        group_info = neonize_client.create_group(
            name=request.name,
            participants=member_jids
        )

        return {
            "status": "success",
            "group_jid": group_info.JID,
            "name": group_info.Name
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/check-whatsapp/{phone}")
async def check_whatsapp(phone: str):
    """Check if number is on WhatsApp"""
    try:
        results = neonize_client.is_on_whatsapp(phone)
        is_registered = len(results) > 0 and results[0].IsIn

        return {
            "phone": phone,
            "is_on_whatsapp": is_registered
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- WEBHOOK TO N8N ---

async def forward_to_n8n(event_type: str, data: dict):
    """Forward neonize events to n8n webhook"""
    payload = {
        "event_type": event_type,
        "timestamp": datetime.now().isoformat(),
        "data": data
    }

    async with httpx.AsyncClient() as client:
        try:
            await client.post(N8N_WEBHOOK_URL, json=payload, timeout=5.0)
        except Exception as e:
            print(f"Failed to forward to n8n: {e}")

# --- NEONIZE EVENT HANDLERS ---

def setup_neonize_handlers():
    """Setup neonize event handlers yang forward ke n8n"""

    @neonize_client.event
    def on_message(client: NewClient, event: MessageEv):
        """Forward incoming messages to n8n"""

        # Skip our own messages
        if event.Info.MessageSource.IsFromMe:
            return

        # Extract message data
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat
        message_text = event.Message.conversation or ""

        # Prepare payload for n8n
        asyncio.run(forward_to_n8n("message_received", {
            "sender": sender,
            "chat": chat,
            "text": message_text,
            "is_group": event.Info.MessageSource.IsGroup,
            "timestamp": event.Info.Timestamp,
            "message_id": event.Info.ID
        }))

        # n8n akan process message ini dan bisa:
        # - Detect keywords (banjir, gempa, dll)
        # - Store ke database
        # - Trigger workflows lain
        # - Send notifications

    @neonize_client.event
    def on_connected(client: NewClient, _):
        print("✅ Neonize connected! Ready to receive n8n commands.")

# --- STARTUP ---

@app.on_event("startup")
async def startup():
    global neonize_client

    # Initialize neonize client
    neonize_client = NewClient("n8n_bridge")
    setup_neonize_handlers()

    # Connect in background thread
    import threading
    thread = threading.Thread(target=neonize_client.connect)
    thread.daemon = True
    thread.start()

    print("🚀 Neonize n8n Bridge started!")

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "neonize_connected": neonize_client.is_connected() if neonize_client else False
    }

# Run with: uvicorn bridge:app --host 0.0.0.0 --port 8000
```

**Deploy**:
```bash
# Install dependencies
pip install fastapi uvicorn httpx

# Run server
uvicorn bridge:app --host 0.0.0.0 --port 8000
```

**n8n Workflow Example**:

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│   Webhook   │────→│ HTTP Request │────→│ Send to WA │
│  (Trigger)  │     │  (Get Data)  │     │ via Bridge │
└─────────────┘     └──────────────┘     └────────────┘
      │
      ↓
  Emergency
   Detected
```

**n8n Node Configuration**:

1. **HTTP Request Node** (Send Message):
```json
{
  "method": "POST",
  "url": "http://localhost:8000/send-message",
  "authentication": "none",
  "body": {
    "phone": "{{ $json.phone }}",
    "message": "{{ $json.alert_message }}"
  }
}
```

2. **Webhook Node** (Receive from Neonize):
```
Webhook URL: https://your-n8n.com/webhook/emergency
Method: POST
Response: Immediately

Workflow:
- Check event_type
- If "message_received", extract text
- Use Switch node untuk routing based on keywords
- Forward ke appropriate workflow
```

---

### 2.3 Metode 2: Direct Python Execution di n8n

**n8n Python Execute Node** dapat menjalankan neonize langsung:

```python
# Di n8n Execute (Python) Node

from neonize.client import NewClient
from neonize.utils import build_jid

# Get data from previous node
phone = items[0]['json']['phone']
message = items[0]['json']['message']

# Initialize client
client = NewClient("n8n_inline")
# Note: Client harus sudah ter-auth sebelumnya

# Send message
jid = build_jid(phone)
client.send_message(jid, text=message)

return [{"json": {"status": "sent", "phone": phone}}]
```

**Kekurangan metode ini**:
- ⚠️ Harus maintain persistent session
- ⚠️ Tidak bisa handle events dengan baik
- ⚠️ Performance overhead tiap execution

**Rekomendasi**: Gunakan **Metode 1 (REST API Bridge)** untuk production.

---

### 2.4 n8n Workflow Examples untuk Emergency Response

#### Workflow 1: Auto-Alert berdasarkan Sensor Data

```
┌─────────────┐     ┌────────────┐     ┌──────────────┐     ┌─────────────┐
│ HTTP Request│────→│ IF Node    │────→│ Format Alert │────→│ Send via WA │
│ (Cek Sensor)│     │ Water > 1m │     │   Message    │     │   Bridge    │
└─────────────┘     └────────────┘     └──────────────┘     └─────────────┘
  Every 5 min           │ Yes
                        ↓
                  ┌──────────┐
                  │ Database │
                  │  Insert  │
                  └──────────┘
```

**n8n JSON**:
```json
{
  "nodes": [
    {
      "name": "Check Water Level",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://api.sensor.gov/water-level/jakarta",
        "method": "GET"
      }
    },
    {
      "name": "IF Water High",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "number": [
            {
              "value1": "={{ $json.water_level }}",
              "operation": "larger",
              "value2": 1.0
            }
          ]
        }
      }
    },
    {
      "name": "Send Alert",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://localhost:8000/send-broadcast",
        "method": "POST",
        "body": {
          "phones": ["628123456789", "628987654321"],
          "message": "⚠️ PERINGATAN: Ketinggian air {{ $json.water_level }}m terdeteksi. Harap waspada!"
        }
      }
    }
  ]
}
```

---

#### Workflow 2: Laporan Warga → Tiket → Dispatch

```
┌─────────────┐     ┌────────────┐     ┌──────────────┐     ┌─────────────┐
│  Webhook    │────→│ Parse Msg  │────→│ Create Ticket│────→│ Notify Team │
│ (from Bridge)│     │ Extract    │     │  (Airtable)  │     │  via WA     │
└─────────────┘     └────────────┘     └──────────────┘     └─────────────┘
  Incoming report         │
                          ↓
                   ┌─────────────┐
                   │ AI Analysis │
                   │  (OpenAI)   │
                   └─────────────┘
                    Categorize &
                     Prioritize
```

**Implementasi**:

1. **Webhook Node**: Terima dari bridge
```json
{
  "event_type": "message_received",
  "data": {
    "sender": "628123456789@s.whatsapp.net",
    "text": "Ada banjir di Jl. Sunter Raya setinggi 50cm"
  }
}
```

2. **Function Node**: Extract info
```javascript
// Regex untuk ekstraksi lokasi & severity
const text = $input.item.json.data.text;
const locationMatch = text.match(/di\s+(.*?)\s/);
const severityMatch = text.match(/setinggi\s+(\d+)/);

return {
  json: {
    reporter: $input.item.json.data.sender,
    location: locationMatch ? locationMatch[1] : 'Unknown',
    severity: severityMatch ? parseInt(severityMatch[1]) : 0,
    original_message: text
  }
};
```

3. **HTTP Request (OpenAI)**: Analisis AI
```json
{
  "url": "https://api.openai.com/v1/chat/completions",
  "method": "POST",
  "body": {
    "model": "gpt-4",
    "messages": [
      {
        "role": "system",
        "content": "Analisis laporan bencana. Return JSON: {category, priority, action_required}"
      },
      {
        "role": "user",
        "content": "{{ $json.original_message }}"
      }
    ]
  }
}
```

4. **Airtable Node**: Create ticket
```json
{
  "operation": "create",
  "table": "Emergency_Reports",
  "fields": {
    "Reporter": "{{ $json.reporter }}",
    "Location": "{{ $json.location }}",
    "Severity": "{{ $json.severity }}",
    "Category": "{{ $json.ai_category }}",
    "Priority": "{{ $json.ai_priority }}",
    "Status": "PENDING"
  }
}
```

5. **HTTP Request (Send to Team)**: Notify via WA
```json
{
  "url": "http://localhost:8000/send-message",
  "method": "POST",
  "body": {
    "phone": "628999999999",  // Team leader
    "message": "🆘 LAPORAN BARU\n\nID: {{ $json.ticket_id }}\nLokasi: {{ $json.location }}\nPrioritas: {{ $json.ai_priority }}\n\nCek dashboard untuk detail."
  }
}
```

---

#### Workflow 3: Scheduled Status Update

```
┌─────────────┐     ┌────────────┐     ┌──────────────┐
│  Cron Node  │────→│ Query DB   │────→│ Format Report│
│ (Every Hour)│     │ Get Stats  │     │   Message    │
└─────────────┘     └────────────┘     └──────────────┘
                                              │
                                              ↓
                                        ┌──────────┐
                                        │ Broadcast│
                                        │  to WA   │
                                        └──────────┘
```

**Cron Expression**: `0 * * * *` (Setiap jam)

**Query DB Node** (PostgreSQL):
```sql
SELECT
  COUNT(*) as total_reports,
  COUNT(CASE WHEN status='RESOLVED' THEN 1 END) as resolved,
  COUNT(CASE WHEN status='PENDING' THEN 1 END) as pending
FROM emergency_reports
WHERE created_at > NOW() - INTERVAL '1 hour'
```

**Format Message**:
```javascript
const stats = $input.item.json;
const message = `📊 HOURLY UPDATE

Total laporan: ${stats.total_reports}
✅ Resolved: ${stats.resolved}
⏳ Pending: ${stats.pending}

Timestamp: ${new Date().toLocaleString('id-ID')}`;

return { json: { message } };
```

---

### 2.5 Advanced: Neonize + n8n + Database + Dashboard

**Full Stack Architecture**:

```
┌──────────────┐
│  WhatsApp    │
│   Citizens   │
└──────┬───────┘
       │
       ↓
┌──────────────┐      ┌────────────┐
│   Neonize    │─────→│ PostgreSQL │
│  Bot Server  │      │  Database  │
└──────┬───────┘      └─────┬──────┘
       │                    │
       ↓                    ↓
┌──────────────┐      ┌────────────┐
│  FastAPI     │      │    n8n     │
│   Bridge     │←─────│ Workflows  │
└──────┬───────┘      └─────┬──────┘
       │                    │
       ↓                    ↓
┌──────────────┐      ┌────────────┐
│   Grafana    │      │  External  │
│  Dashboard   │      │   APIs     │
└──────────────┘      └────────────┘
```

**Docker Compose Setup**:

```yaml
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: emergency_db
      POSTGRES_USER: emergency
      POSTGRES_PASSWORD: secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  # n8n Workflow Automation
  n8n:
    image: n8nio/n8n
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=emergency
      - DB_POSTGRESDB_PASSWORD=secure_password
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres

  # Neonize Bridge API
  neonize_bridge:
    build: ./neonize_bridge
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://emergency:secure_password@postgres:5432/emergency_db
      - N8N_WEBHOOK_URL=http://n8n:5678/webhook/emergency
    volumes:
      - ./neonize_data:/app/data
    depends_on:
      - postgres

  # Grafana Dashboard
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - postgres

volumes:
  postgres_data:
  n8n_data:
  grafana_data:
```

**Database Schema**:

```sql
-- Emergency Reports Table
CREATE TABLE emergency_reports (
    id SERIAL PRIMARY KEY,
    report_id VARCHAR(50) UNIQUE NOT NULL,
    reporter_jid VARCHAR(100) NOT NULL,
    reporter_name VARCHAR(100),
    message TEXT,
    category VARCHAR(50),  -- BANJIR, GEMPA, KEBAKARAN, etc
    severity INT,  -- 1-5
    priority VARCHAR(20),  -- LOW, MEDIUM, HIGH, CRITICAL
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    media_files TEXT[],  -- Array of file paths
    status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, VERIFIED, RESOLVED
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP
);

-- Message Log
CREATE TABLE message_log (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(100),
    direction VARCHAR(10),  -- INCOMING, OUTGOING
    sender_jid VARCHAR(100),
    recipient_jid VARCHAR(100),
    message_type VARCHAR(20),
    content TEXT,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Broadcast History
CREATE TABLE broadcast_history (
    id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(100),
    message TEXT,
    recipients_count INT,
    sent_count INT,
    failed_count INT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_reports_status ON emergency_reports(status);
CREATE INDEX idx_reports_created ON emergency_reports(created_at DESC);
CREATE INDEX idx_messages_created ON message_log(created_at DESC);
```

---

## 3. Arsitektur Teknis

### 3.1 System Design Recommendations

**1. Multi-Layer Architecture**

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (WhatsApp UI, Web Dashboard, Mobile)   │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Application Layer               │
│  (Neonize Bot, n8n Workflows, APIs)     │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Business Logic Layer            │
│  (Rules Engine, AI/ML, Analytics)       │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Data Layer                      │
│  (PostgreSQL, Redis Cache, File Store)  │
└─────────────────────────────────────────┘
```

**2. Microservices Approach**

```
Service 1: Message Handler (Neonize)
├── Receive WhatsApp messages
├── Download media
└── Forward to message queue

Service 2: Report Processor (n8n + Python)
├── Parse messages
├── Extract entities (location, severity)
├── Classify urgency
└── Create tickets

Service 3: Alert Dispatcher (Neonize + n8n)
├── Monitor trigger conditions
├── Generate alerts
└── Broadcast to target audience

Service 4: Analytics Engine
├── Process event logs
├── Generate insights
└── Feed dashboard

Service 5: External Integrations
├── Weather API
├── Government databases
├── GIS/Mapping services
└── Social media monitoring
```

**Message Queue** (Redis/RabbitMQ):
```
Neonize → Queue → Workers → Database
              ↓
           n8n Triggers
```

---

### 3.2 Scalability Considerations

**1. Horizontal Scaling**

```python
# Multiple Neonize instances dengan session berbeda
# Load balancer untuk API requests

# Instance 1: Region Jakarta
client_jakarta = NewClient("emergency_jakarta")

# Instance 2: Region Bandung
client_bandung = NewClient("emergency_bandung")

# Instance 3: Broadcast service
client_broadcast = NewClient("emergency_broadcast")
```

**2. Rate Limiting**

```python
from ratelimit import limits, sleep_and_retry

# WhatsApp has rate limits: ~60 messages/minute
@sleep_and_retry
@limits(calls=50, period=60)
def send_message_with_limit(jid, message):
    client.send_message(jid, text=message)
```

**3. Caching Strategy**

```python
import redis

redis_client = redis.Redis(host='localhost', port=6379)

# Cache contact info
def get_contact_cached(jid):
    cached = redis_client.get(f"contact:{jid}")
    if cached:
        return json.loads(cached)

    contact = client.get_contact(jid)
    redis_client.setex(f"contact:{jid}", 3600, json.dumps(contact))
    return contact
```

---

### 3.3 Security Best Practices

**1. Authentication & Authorization**

```python
# FastAPI dengan JWT
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

@app.post("/send-message")
async def send_message(
    request: SendMessageRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    # Verify JWT token
    verify_token(credentials.credentials)

    # Check role/permissions
    if not has_permission(credentials, "send_message"):
        raise HTTPException(status_code=403, detail="Forbidden")

    # Proceed...
```

**2. Input Validation**

```python
from pydantic import BaseModel, validator

class SendMessageRequest(BaseModel):
    phone: str
    message: str

    @validator('phone')
    def validate_phone(cls, v):
        # Only Indonesian numbers
        if not v.startswith('62'):
            raise ValueError('Must be Indonesian number (62xxx)')
        if len(v) < 11 or len(v) > 15:
            raise ValueError('Invalid phone length')
        return v

    @validator('message')
    def validate_message(cls, v):
        # Prevent abuse
        if len(v) > 1000:
            raise ValueError('Message too long')
        return v
```

**3. Data Protection**

```python
# Encrypt sensitive data
from cryptography.fernet import Fernet

cipher = Fernet(ENCRYPTION_KEY)

def store_report(report_data):
    # Encrypt PII
    encrypted_reporter = cipher.encrypt(report_data['reporter'].encode())

    db.execute("""
        INSERT INTO reports (reporter_encrypted, message, ...)
        VALUES ($1, $2, ...)
    """, encrypted_reporter, ...)
```

**4. Audit Logging**

```python
def audit_log(action, user, details):
    db.execute("""
        INSERT INTO audit_log (action, user_id, details, ip_address, timestamp)
        VALUES ($1, $2, $3, $4, NOW())
    """, action, user, json.dumps(details), request.client.host)

# Usage
audit_log("SEND_BROADCAST", user_id, {
    "recipients": 150,
    "message_preview": message[:50]
})
```

---

## 4. Implementasi Best Practices

### 4.1 Error Handling & Resilience

```python
from tenacity import retry, stop_after_attempt, wait_exponential

class ResilientEmergencyBot:
    def __init__(self):
        self.client = NewClient("resilient_bot")
        self.setup_error_handlers()

    def setup_error_handlers(self):
        @self.client.event
        def on_disconnect(client, event):
            logger.error("Disconnected! Attempting reconnect...")
            self.attempt_reconnect()

        @self.client.event
        def on_stream_error(client, event):
            logger.error(f"Stream error: {event}")
            # Log to monitoring system
            self.report_to_monitoring("stream_error", event)

    @retry(
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=1, min=4, max=60)
    )
    def attempt_reconnect(self):
        """Retry connection with exponential backoff"""
        try:
            self.client.disconnect()
            time.sleep(2)
            self.client.connect()
            logger.info("✅ Reconnected successfully")
        except Exception as e:
            logger.error(f"Reconnect failed: {e}")
            raise

    def send_message_safe(self, jid, message):
        """Send with error handling"""
        try:
            self.client.send_message(jid, text=message)
            return {"status": "success"}

        except SendMessageError as e:
            # Log error
            logger.error(f"Send failed to {jid}: {e}")

            # Store in retry queue
            self.retry_queue.put({
                "jid": jid,
                "message": message,
                "attempts": 0,
                "timestamp": datetime.now()
            })

            return {"status": "queued_for_retry", "error": str(e)}

        except Exception as e:
            # Unknown error
            logger.critical(f"Critical error: {e}")
            self.alert_admin(f"Critical error in send_message: {e}")
            return {"status": "failed", "error": str(e)}
```

---

### 4.2 Testing Strategy

**1. Unit Tests**

```python
import pytest
from unittest.mock import Mock, patch

def test_report_detection():
    """Test emergency keyword detection"""
    bot = EmergencyHelpdesk()

    # Test positive cases
    assert bot.is_emergency_report("Ada banjir di Sunter")
    assert bot.is_emergency_report("GEMPA BESAR!")

    # Test negative cases
    assert not bot.is_emergency_report("Halo selamat pagi")

@patch('neonize.client.NewClient.send_message')
def test_send_alert(mock_send):
    """Test alert sending"""
    broadcaster = EmergencyBroadcaster()

    broadcaster.send_alert(
        region='test',
        alert_type='BANJIR',
        message='Test alert'
    )

    # Verify send_message was called
    assert mock_send.called
    assert 'PERINGATAN BANJIR' in mock_send.call_args[1]['text']
```

**2. Integration Tests**

```python
@pytest.mark.integration
def test_full_report_flow():
    """Test complete report submission flow"""
    # 1. Simulate incoming message
    event = create_mock_message_event(
        sender="628123456789@s.whatsapp.net",
        text="Banjir di Jl. Sunter setinggi 1 meter"
    )

    # 2. Process message
    bot.on_message(bot.client, event)

    # 3. Verify database entry
    report = db.query("SELECT * FROM reports ORDER BY created_at DESC LIMIT 1")
    assert report['category'] == 'BANJIR'
    assert report['severity'] > 0

    # 4. Verify confirmation sent
    assert mock_send_message.called
```

**3. Load Tests**

```python
from locust import HttpUser, task, between

class EmergencyBotLoadTest(HttpUser):
    wait_time = between(1, 3)

    @task(3)
    def send_message(self):
        self.client.post("/send-message", json={
            "phone": "628123456789",
            "message": "Test message"
        })

    @task(1)
    def send_broadcast(self):
        self.client.post("/send-broadcast", json={
            "phones": ["628111111111", "628222222222"],
            "message": "Broadcast test"
        })

# Run: locust -f load_test.py --host http://localhost:8000
```

---

### 4.3 Monitoring & Observability

**1. Prometheus Metrics**

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# Metrics
messages_received = Counter('wa_messages_received_total', 'Total WA messages received')
messages_sent = Counter('wa_messages_sent_total', 'Total WA messages sent')
reports_created = Counter('emergency_reports_total', 'Total emergency reports', ['category'])
response_time = Histogram('wa_response_time_seconds', 'Response time')
active_users = Gauge('wa_active_users', 'Number of active users')

# In event handlers
@client.event
def on_message(client, event):
    messages_received.inc()

    with response_time.time():
        # Process message
        process_message(event)

    if is_report(event):
        reports_created.labels(category='BANJIR').inc()

# Start metrics server
start_http_server(9090)  # Prometheus scrapes this
```

**2. Structured Logging**

```python
import structlog

logger = structlog.get_logger()

@client.event
def on_message(client, event):
    logger.info(
        "message_received",
        sender=event.Info.MessageSource.Sender,
        chat=event.Info.MessageSource.Chat,
        is_group=event.Info.MessageSource.IsGroup,
        message_id=event.Info.ID,
        timestamp=event.Info.Timestamp
    )
```

**3. APM (Application Performance Monitoring)**

```python
# Using Sentry
import sentry_sdk

sentry_sdk.init(
    dsn="https://xxx@sentry.io/xxx",
    traces_sample_rate=1.0,
    profiles_sample_rate=1.0,
)

# Auto-capture exceptions
@client.event
def on_message(client, event):
    with sentry_sdk.start_transaction(op="message", name="process_wa_message"):
        try:
            process_message(event)
        except Exception as e:
            sentry_sdk.capture_exception(e)
            raise
```

---

### 4.4 Configuration Management

```python
# config.py
from pydantic import BaseSettings

class Settings(BaseSettings):
    # Neonize
    NEONIZE_SESSION_NAME: str = "emergency_bot"
    NEONIZE_DATABASE_TYPE: str = "postgres"  # or "sqlite"

    # Database
    DATABASE_URL: str

    # n8n
    N8N_WEBHOOK_URL: str

    # External APIs
    WEATHER_API_KEY: str
    MAPS_API_KEY: str

    # Features
    ENABLE_AI_ANALYSIS: bool = True
    ENABLE_AUTO_REPLY: bool = True

    # Limits
    MAX_BROADCAST_SIZE: int = 100
    MESSAGE_RATE_LIMIT: int = 50  # per minute

    # Monitoring
    SENTRY_DSN: str = None
    PROMETHEUS_PORT: int = 9090

    class Config:
        env_file = ".env"

settings = Settings()

# Usage
client = NewClient(
    session_name=settings.NEONIZE_SESSION_NAME,
    database_type=settings.NEONIZE_DATABASE_TYPE
)
```

**.env file**:
```bash
# Neonize
NEONIZE_SESSION_NAME=emergency_jakarta
NEONIZE_DATABASE_TYPE=postgres

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/emergency_db

# n8n
N8N_WEBHOOK_URL=http://localhost:5678/webhook/emergency

# APIs
WEATHER_API_KEY=your_api_key
MAPS_API_KEY=your_maps_key

# Features
ENABLE_AI_ANALYSIS=true
ENABLE_AUTO_REPLY=true

# Monitoring
SENTRY_DSN=https://xxx@sentry.io/xxx
```

---

## 5. Roadmap Implementasi

### Phase 1: MVP (Minggu 1-2)

**Deliverables**:
- ✅ Neonize bot dasar (receive & send messages)
- ✅ Database setup (PostgreSQL)
- ✅ Keyword detection untuk laporan
- ✅ Auto-reply konfirmasi
- ✅ Basic logging

**Tech Stack**:
- Python 3.10+
- Neonize
- PostgreSQL
- Docker

**Steps**:
1. Setup development environment
2. Implement basic message handler
3. Create database schema
4. Test dengan dummy data
5. Deploy ke staging

---

### Phase 2: n8n Integration (Minggu 3-4)

**Deliverables**:
- ✅ FastAPI bridge API
- ✅ n8n workflows (3-5 use cases)
- ✅ Webhook integration
- ✅ External API integration (Weather, Maps)

**Steps**:
1. Develop REST API bridge
2. Setup n8n instance
3. Create workflow templates
4. Integration testing
5. Documentation

---

### Phase 3: Advanced Features (Minggu 5-8)

**Deliverables**:
- ✅ AI-powered message classification
- ✅ Multi-region support
- ✅ Group coordination features
- ✅ Dashboard (Grafana)
- ✅ Mobile app (optional)

**Steps**:
1. Integrate OpenAI/local LLM
2. Implement multi-instance architecture
3. Build group management features
4. Setup monitoring & dashboard
5. User acceptance testing

---

### Phase 4: Production & Scale (Minggu 9-12)

**Deliverables**:
- ✅ Production deployment
- ✅ Load balancing
- ✅ Backup & disaster recovery
- ✅ Training & documentation
- ✅ Handover

**Steps**:
1. Production hardening
2. Performance optimization
3. Security audit
4. Training tim operator
5. Go-live & monitoring

---

## Kesimpulan

### Keunggulan Neonize untuk Emergency Response:

1. **Real-time Communication** - WhatsApp sebagai platform sudah familiar
2. **Rich Media Support** - Foto, video, lokasi untuk dokumentasi
3. **Scalable Architecture** - Backend Go untuk performa tinggi
4. **Easy Integration** - Python API yang clean dan n8n support
5. **Event-Driven** - Respons cepat terhadap kejadian

### Integrasi n8n Memberikan:

1. **No-Code Workflows** - Tim non-teknis bisa customize
2. **100+ Integrations** - Connect ke berbagai sistem
3. **Visual Workflow** - Mudah dipahami dan di-maintain
4. **Automation** - Reduce manual work
5. **Flexibility** - Easy to adapt untuk use case baru

### Rekomendasi:

**Start Small, Scale Fast**:
1. Mulai dengan MVP (Phase 1)
2. Validasi dengan pilot project di 1 wilayah
3. Iterate berdasarkan feedback
4. Scale ke wilayah lain
5. Continuous improvement

**Technology Choices**:
- **Neonize** untuk WhatsApp automation ✅
- **n8n** untuk workflow & integration ✅
- **PostgreSQL** untuk database ✅
- **FastAPI** untuk REST API ✅
- **Docker** untuk deployment ✅
- **Grafana** untuk monitoring ✅

---

## Resources

- **Neonize Docs**: `/home/user/neonize/docs/`
- **Neonize Examples**: `/home/user/neonize/examples/`
- **n8n Docs**: https://docs.n8n.io
- **FastAPI Docs**: https://fastapi.tiangolo.com
- **PostgreSQL Docs**: https://postgresql.org/docs

---

**Dibuat**: 2025-12-17
**Status**: Draft untuk Review
**Next Steps**: Diskusi dengan stakeholder & pilih use case prioritas
