#!/bin/bash
# Troubleshooting script for n8n workflow

echo "========================================="
echo "1. Checking Database Table Structure"
echo "========================================="
docker exec emergency_postgres psql -U emergency -d emergency_db -c "\d emergency_reports"

echo ""
echo "========================================="
echo "2. Checking Recent n8n Logs"
echo "========================================="
docker logs --tail 50 emergency_n8n 2>&1 | grep -i "error\|workflow\|execution"

echo ""
echo "========================================="
echo "3. Checking Emergency Reports in Database"
echo "========================================="
docker exec emergency_postgres psql -U emergency -d emergency_db -c "SELECT id, sender, disaster_type, severity, message_text, created_at FROM emergency_reports ORDER BY created_at DESC LIMIT 5;"

echo ""
echo "========================================="
echo "4. Testing Neonize API Endpoint"
echo "========================================="
curl -X GET http://localhost:8000/health -H "Content-Type: application/json"

echo ""
echo "========================================="
echo "5. Checking n8n Webhook Status"
echo "========================================="
curl -X POST http://localhost:5678/webhook/emergency \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "message_received",
    "timestamp": "2025-12-18T08:00:00",
    "data": {
      "message_id": "test123",
      "sender": "628123456789@s.whatsapp.net",
      "sender_name": "Test User",
      "chat": "628123456789@s.whatsapp.net",
      "is_group": false,
      "text": "Ada banjir besar di daerah saya!"
    }
  }'

echo ""
echo ""
echo "========================================="
echo "DONE - Check output above for errors"
echo "========================================="
