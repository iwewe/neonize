#!/usr/bin/env python3
"""
Fix n8n workflow - Remove created_at from INSERT to let PostgreSQL auto-generate
"""
import json

# Read fixed workflow
with open('/home/user/neonize/n8n_workflows/emergency_response_workflow_fixed.json', 'r') as f:
    workflow = json.load(f)

# Update Save Emergency Report node
for node in workflow['nodes']:
    if node['name'] == 'Save Emergency Report':
        print("✅ Found Save Emergency Report node")

        columns = node['parameters']['columns']['value']

        # Remove created_at - let PostgreSQL auto-generate
        if 'created_at' in columns:
            del columns['created_at']
            print("   Removed 'created_at' column - will use DEFAULT CURRENT_TIMESTAMP")

        # Ensure we're not inserting id
        if 'id' in columns:
            del columns['id']
            print("   Removed 'id' column - will use auto-increment")

        print("\n   Final columns to insert:")
        for col, val in columns.items():
            print(f"     {col}: {val}")

# Save updated workflow
output_path = '/home/user/neonize/n8n_workflows/emergency_response_workflow_v2.json'
with open(output_path, 'w') as f:
    json.dump(workflow, f, indent=2)

print(f"\n✅ Saved to: {output_path}")
print("\nNext steps:")
print("1. Import emergency_response_workflow_v2.json to n8n")
print("2. Re-assign credentials (PostgreSQL + Header Auth)")
print("3. Activate and test again")
