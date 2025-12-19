#!/bin/bash
# Check and fix database schema for emergency_reports table

echo "========================================="
echo "Checking Database Schema"
echo "========================================="

echo "1. Checking column 'id' definition:"
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT column_name, column_default, is_nullable, data_type
FROM information_schema.columns
WHERE table_name = 'emergency_reports' AND column_name = 'id';
"

echo ""
echo "2. Checking sequence 'emergency_reports_id_seq':"
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT last_value, is_called FROM emergency_reports_id_seq;
"

echo ""
echo "3. Checking if id column uses sequence:"
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT pg_get_serial_sequence('emergency_reports', 'id');
"

echo ""
echo "========================================="
echo "Fixing Schema (if needed)"
echo "========================================="

echo "Step 1: Ensure id column uses sequence..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
ALTER TABLE emergency_reports
  ALTER COLUMN id SET DEFAULT nextval('emergency_reports_id_seq'::regclass);
"

echo "Step 2: Ensure id column is NOT NULL..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
ALTER TABLE emergency_reports
  ALTER COLUMN id SET NOT NULL;
"

echo "Step 3: Reset sequence to 1..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT setval('emergency_reports_id_seq', 1, false);
"

echo ""
echo "Step 4: Verify fixes..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'emergency_reports' AND column_name = 'id';
"

echo ""
echo "========================================="
echo "Testing Auto-Increment"
echo "========================================="

echo "Inserting test row (should get id=1)..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
INSERT INTO emergency_reports
  (sender, sender_name, chat_id, is_group, message_text, disaster_type, severity, status)
VALUES
  ('test@s.whatsapp.net', 'Test Auto Inc', 'test@s.whatsapp.net', false, 'Test auto increment', 'flood', 3, 'pending')
RETURNING id, sender_name, created_at;
"

echo ""
echo "Checking if id=1 was assigned..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT id, sender_name, created_at FROM emergency_reports ORDER BY created_at DESC LIMIT 1;
"

echo ""
echo "Cleaning up test data..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
DELETE FROM emergency_reports WHERE sender = 'test@s.whatsapp.net';
"

echo ""
echo "Resetting sequence again..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT setval('emergency_reports_id_seq', 1, false);
"

echo ""
echo "========================================="
echo "DONE - Schema fixed and verified"
echo "========================================="
echo ""
echo "If test showed id=1, schema is OK! ✅"
echo "If test showed id=0, there's a deeper issue ❌"
