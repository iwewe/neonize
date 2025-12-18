#!/usr/bin/env python3
"""
Fix n8n workflow - Update Switch Event Type to use $json.body.event_type
"""
import json
import sys

# Read workflow JSON
with open('/home/user/neonize/n8n_workflows/emergency_response_workflow.json', 'r') as f:
    workflow = json.load(f)

# Fix Switch Event Type node
fixed_count = 0
for node in workflow['nodes']:
    if node['name'] == 'Switch Event Type':
        print(f"✅ Found Switch Event Type node")

        # Update conditions to use $json.body.event_type
        for rule in node['parameters']['rules']['values']:
            for condition in rule['conditions']['conditions']:
                old_value = condition['leftValue']
                if '$json.event_type' in old_value:
                    # Replace $json.event_type with $json.body.event_type
                    condition['leftValue'] = old_value.replace('$json.event_type', '$json.body.event_type')
                    print(f"   Fixed: {old_value} → {condition['leftValue']}")
                    fixed_count += 1

# Also fix Process Message node to use $json.body.data
for node in workflow['nodes']:
    if node['name'] == 'Process Message':
        print(f"\n✅ Found Process Message node")
        old_code = node['parameters']['jsCode']

        # Update to access data from $json.body
        new_code = old_code.replace(
            "const item = $input.all()[0].json;",
            "const item = $input.all()[0].json.body || $input.all()[0].json;"
        )

        node['parameters']['jsCode'] = new_code
        print(f"   Fixed: Updated to handle $json.body structure")
        fixed_count += 1

# Save fixed workflow
output_path = '/home/user/neonize/n8n_workflows/emergency_response_workflow_fixed.json'
with open(output_path, 'w') as f:
    json.dump(workflow, f, indent=2)

print(f"\n✅ Fixed {fixed_count} issues")
print(f"✅ Saved to: {output_path}")
print(f"\nNext steps:")
print(f"1. Go to n8n UI → Workflows")
print(f"2. Import the FIXED workflow: emergency_response_workflow_fixed.json")
print(f"3. Activate the workflow")
print(f"4. Test again!")
