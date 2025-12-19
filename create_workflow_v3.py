#!/usr/bin/env python3
"""
Create workflow v3 - Use Code node with raw SQL instead of Postgres node
This bypasses potential n8n Postgres node bugs
"""
import json

# Read workflow v2
with open('/home/user/neonize/n8n_workflows/emergency_response_workflow_v2.json', 'r') as f:
    workflow = json.load(f)

# Find and replace "Save Emergency Report" Postgres node with Code node
for i, node in enumerate(workflow['nodes']):
    if node['name'] == 'Save Emergency Report':
        print("✅ Found Save Emergency Report (Postgres node)")
        print("   Replacing with Code node using raw SQL INSERT...")

        # Create new Code node
        new_node = {
            "parameters": {
                "mode": "runOnceForAllItems",
                "jsCode": """// Execute raw SQL INSERT to avoid n8n Postgres node id=0 bug
const items = $input.all();

// Database connection config
const dbConfig = {
  host: 'postgres',
  port: 5432,
  database: 'emergency_db',
  user: 'emergency',
  password: process.env.POSTGRES_PASSWORD || 'emergency123'
};

// Prepare insert values from first item
const data = items[0].json;
const sender = data.sender || '';
const senderName = data.sender_name || 'Unknown';
const chatId = data.chat || '';
const isGroup = data.is_group || false;
const messageText = data.text || '';
const disasterType = data.disaster_type || 'other';
const severity = data.severity || 1;

// Build SQL query - id will auto-increment, created_at will use DEFAULT
const sql = `
INSERT INTO emergency_reports
  (sender, sender_name, chat_id, is_group, message_text, disaster_type, severity, status)
VALUES
  ($1, $2, $3, $4, $5, $6, $7, 'pending')
RETURNING id, sender, sender_name, disaster_type, severity, created_at
`;

const values = [sender, senderName, chatId, isGroup, messageText, disasterType, severity];

// Execute using pg library (if available)
// For now, we'll use n8n's built-in database execution
// This is a workaround - the actual implementation needs n8n's database helper

// Return data to pass to next node
return items.map(item => ({
  json: {
    ...item.json,
    db_insert_pending: true,
    sql_query: sql,
    sql_values: values
  }
}));

// NOTE: This is a placeholder. The actual SQL execution should be done via:
// 1. n8n's HTTP Request node to a custom API endpoint that executes SQL
// 2. Or using PostgreSQL node with proper configuration
// 3. Or using Execute Command node with psql
"""
            },
            "id": node['id'],
            "name": "Save Emergency Report",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": node['position']
        }

        # Replace node
        workflow['nodes'][i] = new_node
        print("   ✅ Replaced with Code node")

# Save workflow v3
output_path = '/home/user/neonize/n8n_workflows/emergency_response_workflow_v3_code.json'
with open(output_path, 'w') as f:
    json.dump(workflow, f, indent=2)

print(f"\n⚠️  Workflow v3 created but needs manual completion!")
print(f"   Saved to: {output_path}")
print("\nThe Code node approach has limitations in n8n.")
print("Better solution: Use Execute Command node with psql")
