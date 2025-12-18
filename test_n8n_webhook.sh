#!/bin/bash
# Test n8n webhook dengan payload sesuai format neonize

echo "========================================="
echo "Testing n8n Webhook with Neonize Format"
echo "========================================="
echo ""

# Get n8n webhook URL from docker
WEBHOOK_URL="http://localhost:5678/webhook/emergency"

echo "📡 Sending test payload to: $WEBHOOK_URL"
echo ""

# Test 1: Message Received Event
echo "Test 1: Message Received (Emergency Keywords)"
echo "-------------------------------------------"

RESPONSE=$(curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "message_received",
    "timestamp": "2025-12-18T08:30:00.000Z",
    "data": {
      "event_id": "msg_TEST123",
      "message_id": "TEST123",
      "sender": "628123456789@s.whatsapp.net",
      "sender_name": "Test User",
      "chat": "628123456789@s.whatsapp.net",
      "is_group": false,
      "timestamp": "2025-12-18T08:30:00",
      "text": "Ada banjir besar di daerah saya! Air sudah setinggi 1 meter dan sangat berbahaya!",
      "media_type": "text",
      "location": null
    }
  }' \
  -w "\nHTTP_STATUS:%{http_code}\n" \
  -s)

echo "Response:"
echo "$RESPONSE"
echo ""
echo ""

# Test 2: Message Without Emergency Keywords
echo "Test 2: Message WITHOUT Emergency Keywords"
echo "-------------------------------------------"

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "message_received",
    "timestamp": "2025-12-18T08:31:00.000Z",
    "data": {
      "event_id": "msg_TEST456",
      "message_id": "TEST456",
      "sender": "628987654321@s.whatsapp.net",
      "sender_name": "Normal User",
      "chat": "628987654321@s.whatsapp.net",
      "is_group": false,
      "timestamp": "2025-12-18T08:31:00",
      "text": "Halo, apa kabar? Cuaca hari ini cerah ya.",
      "media_type": "text",
      "location": null
    }
  }' \
  -w "\nHTTP_STATUS:%{http_code}\n" \
  -s

echo ""
echo ""

# Test 3: Bot Connected Event
echo "Test 3: Bot Connected Event"
echo "-------------------------------------------"

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "bot_connected",
    "timestamp": "2025-12-18T08:32:00.000Z",
    "data": {
      "timestamp": "2025-12-18T08:32:00.000Z",
      "session": "emergency_bot"
    }
  }' \
  -w "\nHTTP_STATUS:%{http_code}\n" \
  -s

echo ""
echo ""

# Check n8n executions
echo "========================================="
echo "Checking Recent n8n Executions"
echo "========================================="
echo ""
echo "Please check n8n UI at: http://localhost:5678"
echo "Go to: Executions tab"
echo ""
echo "You should see 3 new executions:"
echo "  1. ✅ Message with emergency keywords -> Should save to DB and auto-reply"
echo "  2. ⚠️  Message without emergency -> Should stop at Filter node"
echo "  3. ✅ Bot connected -> Should log to 'Log Bot Status' node"
echo ""

# Check database for new records
echo "========================================="
echo "Checking Database for New Reports"
echo "========================================="
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT
  id,
  sender_name,
  disaster_type,
  severity,
  LEFT(message_text, 50) as message_preview,
  created_at
FROM emergency_reports
ORDER BY created_at DESC
LIMIT 3;
" 2>&1

echo ""
echo "========================================="
echo "DONE - Review output above"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Check n8n Executions tab for details"
echo "2. Click on each execution to see which nodes ran"
echo "3. Look for errors in any nodes (red X marks)"
echo ""
