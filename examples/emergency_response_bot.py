#!/usr/bin/env python3
"""
Emergency Response Chatbot
===========================

Chatbot WhatsApp untuk tanggap darurat bencana menggunakan Neonize.

Features:
- Penerimaan laporan bencana dari warga
- Auto-reply & konfirmasi laporan
- Tracking lokasi & media (foto/video)
- Broadcasting alert ke wilayah terdampak
- Group coordination untuk tim lapangan
- Helpdesk FAQ otomatis

Author: Neonize Team
License: Apache 2.0
"""

from neonize.client import NewClient
from neonize.events import MessageEv, ConnectedEv, DisconnectedEv
from neonize.utils import build_jid
from datetime import datetime
from collections import defaultdict
import json
import re
import logging
import os

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class EmergencyResponseBot:
    """
    Main bot class untuk emergency response
    """

    def __init__(self, session_name="emergency_bot"):
        # Create sessions directory if it doesn't exist
        os.makedirs("sessions", exist_ok=True)

        # Store database in sessions directory for persistence
        database_path = f"sessions/{session_name}.db"
        print(f"Using database: {database_path}")

        self.client = NewClient(database_path)

        # In-memory storage (production: gunakan database)
        self.reports = {}  # {report_id: report_data}
        self.active_teams = {}  # {group_jid: team_info}

        # Configuration
        self.EMERGENCY_KEYWORDS = ['banjir', 'gempa', 'kebakaran', 'longsor', 'tsunami', 'angin']
        self.ADMIN_NUMBERS = ['628123456789@s.whatsapp.net']  # List admin untuk notifikasi

        # FAQ knowledge base
        self.faq_database = {
            'shelter': """📍 *LOKASI SHELTER TERDEKAT*

1. GOR Sunter - Jl. Sunter Permai
2. Balai Warga RW 08 - Jl. Ancol
3. Gereja Santo Bellarminus - Sunter

Kapasitas: ~500 orang
Fasilitas: Dapur umum, MCK, Tenda

Google Maps akan dikirim berikutnya.""",

            'logistik': """📦 *INFO LOGISTIK*

Kebutuhan saat ini:
✅ Air mineral (tersedia)
⚠️ Makanan instan (menipis)
❌ Selimut (habis)
✅ Obat-obatan (tersedia)

Titik donasi:
- Posko GOR Sunter (24 jam)
- Kelurahan Sunter Agung (08:00-20:00)

Info: 0812-xxxx-xxxx""",

            'evakuasi': """🚨 *PANDUAN EVAKUASI*

SEGERA EVAKUASI jika:
• Air mencapai lutut orang dewasa
• Arus air deras
• Petugas memerintahkan

BAWA:
✓ Dokumen penting (KTP, KK)
✓ Obat rutin
✓ Powerbank & charger
✓ Uang tunai secukupnya

JANGAN:
✗ Membawa barang berat
✗ Panik
✗ Kembali tanpa izin petugas""",

            'hotline': """☎️ *HOTLINE DARURAT*

🚨 Emergency: 112
🚒 Pemadam: 113
🚑 Ambulans: 118
👮 Polisi: 110

🏛️ BPBD Jakarta: 021-xxxx
⛑️ PMI Jakarta: 021-yyyy

24/7 Available"""
        }

        # Setup event handlers
        self._setup_handlers()

    def _setup_handlers(self):
        """Register event handlers"""

        @self.client.event(ConnectedEv)
        def on_connected(client: NewClient, event: ConnectedEv):
            logger.info("✅ Emergency Bot Connected!")
            self._broadcast_to_admins("🟢 Emergency Bot is ONLINE")

        @self.client.event(DisconnectedEv)
        def on_disconnected(client: NewClient, event: DisconnectedEv):
            logger.warning("⚠️ Emergency Bot Disconnected!")

        @self.client.event(MessageEv)
        def on_message(client: NewClient, event: MessageEv):
            self._handle_message(event)

    # ==================== MESSAGE HANDLERS ====================

    def _handle_message(self, event: MessageEv):
        """Main message handler - routing ke handler spesifik"""

        # Skip our own messages
        if event.Info.MessageSource.IsFromMe:
            return

        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat
        is_group = event.Info.MessageSource.IsGroup
        msg = event.Message

        try:
            # TEXT MESSAGE
            if msg.conversation:
                text = msg.conversation

                # Route berdasarkan context
                if is_group:
                    self._handle_group_message(event, text)
                else:
                    self._handle_private_message(event, text)

            # LOCATION MESSAGE
            elif msg.locationMessage:
                self._handle_location(event)

            # MEDIA MESSAGE (foto/video bukti)
            elif msg.imageMessage or msg.videoMessage:
                self._handle_media(event)

        except Exception as e:
            logger.error(f"Error handling message: {e}")
            self.client.send_message(
                chat,
                text="⚠️ Maaf, terjadi kesalahan. Silakan coba lagi atau hubungi admin."
            )

    def _handle_private_message(self, event: MessageEv, text: str):
        """Handle pesan private (1-on-1)"""
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat

        text_lower = text.lower().strip()

        # 1. EMERGENCY REPORT DETECTION
        if self._is_emergency_report(text):
            self._process_emergency_report(event, text)

        # 2. FAQ QUERIES
        elif any(word in text_lower for word in ['shelter', 'posko', 'pengungsian']):
            self._send_faq_response(chat, 'shelter')

        elif any(word in text_lower for word in ['logistik', 'donasi', 'bantuan']):
            self._send_faq_response(chat, 'logistik')

        elif any(word in text_lower for word in ['evakuasi', 'mengungsi']):
            self._send_faq_response(chat, 'evakuasi')

        elif any(word in text_lower for word in ['telepon', 'hotline', 'kontak']):
            self._send_faq_response(chat, 'hotline')
            # Kirim kontak card juga
            self.client.send_contact(
                jid=chat,
                name="BPBD Jakarta",
                number="+62215551234"
            )

        # 3. GREETINGS
        elif any(word in text_lower for word in ['halo', 'hai', 'help', 'bantuan', 'start']):
            self._send_welcome_message(chat)

        # 4. UNKNOWN QUERY
        else:
            self._send_menu(chat)

    def _handle_group_message(self, event: MessageEv, text: str):
        """Handle pesan di group (koordinasi tim)"""
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat

        text_lower = text.lower().strip()

        # COMMANDS untuk koordinasi tim
        if text_lower == '/sitrep':
            # Kirim template situation report
            template = """📊 *SITUATION REPORT TEMPLATE*

Waktu: [HH:MM]
Lokasi: [Nama Lokasi]
Status: [AMAN/BERBAHAYA/TERKENDALI]

👥 Korban:
- Terluka: [jumlah]
- Meninggal: [jumlah]
- Hilang: [jumlah]

📍 Kondisi Lapangan:
[Deskripsi singkat]

🆘 Kebutuhan Mendesak:
[Logistik yang diperlukan]

Pelapor: @{sender_name}"""

            self.client.send_message(chat, text=template)

        elif text_lower == '/sos':
            # Emergency dari tim lapangan
            self.client.send_message(
                chat,
                text=f"🆘 *SOS DITERIMA*\n\nDari: @{sender.split('@')[0]}\n\nKoordinator akan segera merespons!"
            )
            # Notify admin
            self._broadcast_to_admins(f"🆘 SOS from {sender} in group {chat}")

        elif text_lower == '/help':
            help_text = """📱 *COMMAND AVAILABLE*

/sitrep - Template laporan situasi
/sos - Minta bantuan darurat
/help - Tampilkan bantuan

Selain command:
📍 Share location untuk tracking
📸 Kirim foto kondisi lapangan
🎤 Voice note untuk laporan cepat"""

            self.client.send_message(chat, text=help_text)

        # Track emergency reports di group
        elif self._is_emergency_report(text):
            self._process_emergency_report(event, text)

    def _handle_location(self, event: MessageEv):
        """Handle location sharing"""
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat
        msg = event.Message

        lat = msg.locationMessage.degreesLatitude
        lon = msg.locationMessage.degreesLongitude

        # Update laporan terakhir dari user ini dengan lokasi
        updated = False
        for report_id, data in self.reports.items():
            if data['reporter'] == sender and data.get('location') is None:
                data['location'] = {'lat': lat, 'lon': lon}
                updated = True

                response = f"""📍 *LOKASI TERSIMPAN*

ID Laporan: {report_id}
Koordinat: {lat}, {lon}
Maps: https://maps.google.com/?q={lat},{lon}

✅ Tim terdekat akan segera dihubungi."""

                self.client.send_message(chat, text=response)

                # Notify command center
                self._notify_command_center(report_id, data)
                break

        if not updated:
            # Lokasi tanpa laporan sebelumnya
            self.client.send_message(
                chat,
                text=f"📍 Lokasi diterima: {lat}, {lon}\n\nJika ada laporan bencana, silakan kirim deskripsinya."
            )

    def _handle_media(self, event: MessageEv):
        """Handle media (foto/video)"""
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat
        msg = event.Message

        try:
            # Download media
            media_data = self.client.download_any(msg)

            # Find related report
            for report_id, data in self.reports.items():
                if data['reporter'] == sender:
                    # Simpan media (production: upload ke S3/storage)
                    filename = f"{report_id}_{len(data['media'])}.jpg"

                    # In production, save to proper storage
                    # For now, just track filename
                    data['media'].append(filename)

                    self.client.send_message(
                        chat,
                        text=f"✅ Foto/video diterima untuk laporan {report_id}\n\nTerima kasih atas dokumentasinya!"
                    )
                    return

            # Media tanpa report context
            self.client.send_message(
                chat,
                text="📸 Media diterima.\n\nJika ini terkait laporan bencana, mohon kirim deskripsi teksnya."
            )

        except Exception as e:
            logger.error(f"Error downloading media: {e}")
            self.client.send_message(
                chat,
                text="⚠️ Gagal mengunduh media. Silakan coba lagi."
            )

    # ==================== EMERGENCY REPORT PROCESSING ====================

    def _is_emergency_report(self, text: str) -> bool:
        """Deteksi apakah pesan adalah laporan bencana"""
        text_lower = text.lower()

        # Check keywords
        has_keyword = any(keyword in text_lower for keyword in self.EMERGENCY_KEYWORDS)

        # Additional heuristics (minimal 10 karakter untuk avoid false positive)
        is_long_enough = len(text) >= 10

        return has_keyword and is_long_enough

    def _process_emergency_report(self, event: MessageEv, text: str):
        """Process laporan bencana"""
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat

        # Generate report ID
        report_id = f"RPT{datetime.now().strftime('%Y%m%d%H%M%S')}"

        # Extract category
        category = self._extract_category(text)

        # Estimate severity (simple keyword-based)
        severity = self._estimate_severity(text)

        # Create report record
        report_data = {
            'report_id': report_id,
            'reporter': sender,
            'reporter_name': event.Info.PushName or 'Unknown',
            'timestamp': datetime.now().isoformat(),
            'message': text,
            'category': category,
            'severity': severity,
            'location': None,
            'media': [],
            'status': 'PENDING',
            'is_group': event.Info.MessageSource.IsGroup,
            'chat': chat
        }

        self.reports[report_id] = report_data

        # Send confirmation to reporter
        severity_emoji = '🔴' if severity >= 4 else '🟡' if severity >= 2 else '🟢'

        confirmation = f"""✅ *LAPORAN DITERIMA*

ID: {report_id}
Kategori: {category.upper()}
Tingkat: {severity_emoji} {severity}/5
Waktu: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}

Status: Sedang diverifikasi oleh tim

📍 *LANGKAH SELANJUTNYA:*
1. Kirim lokasi Anda (Share Location)
2. Kirim foto/video jika ada
3. Tunggu konfirmasi dari tim

Terima kasih atas laporannya! 🙏"""

        self.client.send_message(chat, text=confirmation)

        # Send quick poll untuk validasi tingkat urgensi
        try:
            poll = self.client.build_poll_vote_creation(
                name="Konfirmasi Tingkat Urgensi",
                options=["🔴 SANGAT DARURAT", "🟡 MENDESAK", "🟢 TERKENDALI"],
                selectable_options_count=1
            )
            self.client.send_message(chat, poll_creation=poll)
        except Exception as e:
            logger.warning(f"Failed to send poll: {e}")

        # Notify admins
        admin_notif = f"""🚨 *LAPORAN BARU*

ID: {report_id}
Dari: {report_data['reporter_name']} ({sender})
Kategori: {category}
Severity: {severity}/5

Pesan:
{text[:200]}...

Dashboard: [link to dashboard]"""

        self._broadcast_to_admins(admin_notif)

        # Log event
        logger.info(f"New report created: {report_id} - {category} - severity {severity}")

    def _extract_category(self, text: str) -> str:
        """Extract disaster category from text"""
        text_lower = text.lower()

        if 'banjir' in text_lower:
            return 'BANJIR'
        elif any(word in text_lower for word in ['gempa', 'guncangan']):
            return 'GEMPA'
        elif 'kebakaran' in text_lower or 'api' in text_lower:
            return 'KEBAKARAN'
        elif 'longsor' in text_lower:
            return 'LONGSOR'
        elif 'tsunami' in text_lower:
            return 'TSUNAMI'
        elif any(word in text_lower for word in ['angin', 'puting beliung', 'tornado']):
            return 'ANGIN_KENCANG'
        else:
            return 'LAINNYA'

    def _estimate_severity(self, text: str) -> int:
        """
        Estimate severity dari text (1-5)
        5 = paling parah
        """
        text_lower = text.lower()
        severity = 1

        # High severity keywords
        high_severity = ['parah', 'besar', 'korban', 'meninggal', 'banyak', 'hebat']
        if any(word in text_lower for word in high_severity):
            severity += 2

        # Medium severity keywords
        medium_severity = ['lumayan', 'cukup', 'sedang', 'terluka']
        if any(word in text_lower for word in medium_severity):
            severity += 1

        # Urgent indicators
        urgent = ['segera', 'darurat', 'cepat', 'tolong', 'bantuan']
        if any(word in text_lower for word in urgent):
            severity += 1

        return min(severity, 5)  # Cap at 5

    # ==================== BROADCASTING ====================

    def broadcast_alert(self, region: str, alert_type: str, message: str, target_jids: list):
        """
        Broadcast emergency alert

        Args:
            region: Nama wilayah
            alert_type: TSUNAMI, BANJIR, GEMPA, etc
            message: Isi peringatan
            target_jids: List JID penerima
        """
        alert_headers = {
            'TSUNAMI': '🌊 *PERINGATAN TSUNAMI*',
            'BANJIR': '💧 *PERINGATAN BANJIR*',
            'GEMPA': '🌍 *PERINGATAN GEMPA*',
            'KEBAKARAN': '🔥 *PERINGATAN KEBAKARAN*',
            'LONGSOR': '⛰️ *PERINGATAN LONGSOR*'
        }

        full_message = f"""{alert_headers.get(alert_type, '⚠️ PERINGATAN')}

{message}

📅 Waktu: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}
📍 Wilayah: {region.upper()}

⚠️ SEGERA LAKUKAN:
1. Tetap tenang
2. Ikuti instruksi petugas
3. Hubungi 112 jika darurat
4. Jangan sebar hoax

#EmergencyAlert #BNPB"""

        sent_count = 0
        failed_count = 0

        for jid in target_jids:
            try:
                self.client.send_message(jid, text=full_message)
                sent_count += 1
                logger.info(f"Alert sent to {jid}")
            except Exception as e:
                failed_count += 1
                logger.error(f"Failed to send alert to {jid}: {e}")

        logger.info(f"Broadcast completed: {sent_count} sent, {failed_count} failed")

        return {
            'sent': sent_count,
            'failed': failed_count,
            'total': len(target_jids)
        }

    def _broadcast_to_admins(self, message: str):
        """Send message to all admins"""
        for admin_jid in self.ADMIN_NUMBERS:
            try:
                self.client.send_message(admin_jid, text=message)
            except Exception as e:
                logger.error(f"Failed to notify admin {admin_jid}: {e}")

    # ==================== GROUP COORDINATION ====================

    def create_emergency_team(self, team_name: str, members: list, mission: str):
        """
        Create emergency response team group

        Args:
            team_name: Nama tim
            members: List phone numbers (e.g., ['628123456789'])
            mission: Deskripsi misi
        """
        try:
            # Convert to JIDs
            member_jids = [build_jid(phone) for phone in members]

            # Create group
            group_info = self.client.create_group(
                name=f"🚨 {team_name}",
                participants=member_jids
            )

            group_jid = group_info.JID

            # Set group description
            self.client.set_group_topic(
                jid=group_jid,
                topic=f"""🎯 MISI: {mission}

📋 PROTOKOL OPERASI:
- Laporkan status setiap 30 menit
- Gunakan /sitrep untuk situation report
- Gunakan /sos untuk emergency
- Share lokasi saat operasi

⏰ Dibuat: {datetime.now().strftime('%d/%m/%Y %H:%M')}
🤖 Bot: Aktif untuk monitoring"""
            )

            # Send welcome message
            welcome = f"""✅ *TIM DARURAT DIBENTUK*

👥 Anggota: {len(members)} orang
🎯 Misi: {mission}

⚠️ COMMAND CEPAT:
• /sitrep - Laporan situasi
• /sos - Emergency
• /help - Bantuan

📍 Share lokasi real-time
📸 Dokumentasi kondisi
🎤 Voice note untuk update cepat

Stay safe, team! 🙏"""

            self.client.send_message(group_jid, text=welcome)

            # Save team info
            self.active_teams[group_jid] = {
                'name': team_name,
                'mission': mission,
                'created': datetime.now().isoformat(),
                'members': member_jids,
                'status': 'ACTIVE'
            }

            logger.info(f"Emergency team created: {group_jid}")

            return group_jid

        except Exception as e:
            logger.error(f"Failed to create emergency team: {e}")
            raise

    # ==================== FAQ & HELPDESK ====================

    def _send_faq_response(self, chat_jid: str, topic: str):
        """Send FAQ response"""
        if topic in self.faq_database:
            self.client.send_message(chat_jid, text=self.faq_database[topic])
        else:
            self.client.send_message(
                chat_jid,
                text="⚠️ Maaf, informasi tidak tersedia."
            )

    def _send_welcome_message(self, chat_jid: str):
        """Send welcome/greeting message"""
        welcome = """👋 *Halo!*

Saya adalah Bot Tanggap Darurat Bencana.

Saya bisa membantu:
📍 Lokasi shelter & posko
📦 Info logistik & donasi
🚨 Panduan evakuasi
☎️ Hotline darurat
🆘 Menerima laporan bencana

*UNTUK LAPORAN DARURAT:*
Langsung kirim pesan dengan deskripsi kejadian, contoh:
"Ada banjir di Jl. Sunter setinggi 1 meter"

*UNTUK INFORMASI:*
Ketik kata kunci seperti:
- "shelter" untuk lokasi pengungsian
- "donasi" untuk info logistik
- "evakuasi" untuk panduan
- "hotline" untuk nomor darurat

Bagaimana saya bisa membantu Anda?"""

        self.client.send_message(chat_jid, text=welcome)

    def _send_menu(self, chat_jid: str):
        """Send interactive menu"""
        menu = """🤖 *MENU UTAMA*

Pilih topik:

1️⃣ Lokasi Shelter & Posko
2️⃣ Info Logistik & Donasi
3️⃣ Panduan Evakuasi
4️⃣ Hotline Darurat
5️⃣ Laporkan Bencana

Balas dengan nomor (1-5) atau kata kunci.

Atau langsung kirim laporan jika ada kejadian darurat."""

        self.client.send_message(chat_jid, text=menu)

    # ==================== NOTIFICATION & REPORTING ====================

    def _notify_command_center(self, report_id: str, report_data: dict):
        """
        Notify command center about new report
        Production: Kirim ke sistem dispatch, webhook, dll
        """
        logger.info(f"Notifying command center for report: {report_id}")

        # Example: Send to command center API
        # requests.post('https://command-center.gov/api/reports', json=report_data)

        # For now, just log
        logger.info(f"Report {report_id} forwarded to command center")

    def get_report_summary(self):
        """Get summary of all reports"""
        total = len(self.reports)
        by_category = defaultdict(int)
        by_status = defaultdict(int)

        for report in self.reports.values():
            by_category[report['category']] += 1
            by_status[report['status']] += 1

        return {
            'total_reports': total,
            'by_category': dict(by_category),
            'by_status': dict(by_status),
            'latest_report_id': list(self.reports.keys())[-1] if self.reports else None
        }

    # ==================== MAIN ====================

    def run(self):
        """Start the bot"""
        logger.info("Starting Emergency Response Bot...")
        logger.info("Press Ctrl+C to stop")

        try:
            self.client.connect()
        except KeyboardInterrupt:
            logger.info("\n👋 Bot stopped by user")
        except Exception as e:
            logger.error(f"Bot crashed: {e}")
            raise


# ==================== USAGE EXAMPLE ====================

def main():
    """Main entry point"""

    # Initialize bot
    bot = EmergencyResponseBot(session_name="emergency_jakarta")

    # Optional: Pre-configure admin numbers
    bot.ADMIN_NUMBERS = [
        '628123456789@s.whatsapp.net',  # Admin 1
        '628987654321@s.whatsapp.net',  # Admin 2
    ]

    # Run bot
    bot.run()

    # ===== EXAMPLES OF ADDITIONAL FEATURES =====

    # Example 1: Broadcast alert
    # bot.broadcast_alert(
    #     region='Jakarta Utara',
    #     alert_type='BANJIR',
    #     message='Air sungai Ciliwung meluap. Warga RW 05-08 harap segera evakuasi.',
    #     target_jids=['628111111111@s.whatsapp.net', '628222222222@s.whatsapp.net']
    # )

    # Example 2: Create emergency team
    # team_jid = bot.create_emergency_team(
    #     team_name='Tim Evakuasi Sektor A',
    #     members=['628123456789', '628987654321'],
    #     mission='Evakuasi warga RW 05'
    # )

    # Example 3: Get report summary
    # summary = bot.get_report_summary()
    # print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
