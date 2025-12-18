#!/bin/bash
# Clean emergency_reports table and reset sequence

echo "========================================="
echo "Cleaning emergency_reports table"
echo "========================================="

echo "Step 1: Current data in table"
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT id, sender_name, disaster_type, created_at
FROM emergency_reports
ORDER BY id
LIMIT 10;
"

echo ""
echo "Step 2: Deleting all records..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
DELETE FROM emergency_reports;
"

echo ""
echo "Step 3: Resetting sequence..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
ALTER SEQUENCE emergency_reports_id_seq RESTART WITH 1;
"

echo ""
echo "Step 4: Verify table is empty..."
RESULT=$(docker exec emergency_postgres psql -U emergency -d emergency_db -t -c "
SELECT COUNT(*) FROM emergency_reports;
")

echo "Total rows: $RESULT"

if [ "$RESULT" -eq 0 ]; then
    echo "✅ Table is clean!"
else
    echo "❌ WARNING: Table still has $RESULT rows!"
fi

echo ""
echo "Step 5: Verify sequence reset..."
docker exec emergency_postgres psql -U emergency -d emergency_db -c "
SELECT last_value FROM emergency_reports_id_seq;
"

echo ""
echo "========================================="
echo "DONE - Database cleaned and ready"
echo "========================================="
echo ""
echo "Next: Run ./test_n8n_webhook.sh to test"
