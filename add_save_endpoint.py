#!/usr/bin/env python3
"""
Add /save-emergency-report endpoint to neonize n8n_bridge.py

This endpoint will handle database INSERT directly, bypassing n8n Postgres node
"""

endpoint_code = '''
# Add this to n8n_bridge.py before the error handlers section

@app.post("/save-emergency-report", response_model=ApiResponse)
async def save_emergency_report(
    data: dict,
    api_key: str = Depends(verify_api_key)
):
    """
    Save emergency report to database

    This endpoint bypasses n8n Postgres node to avoid id=0 bug

    Example:
    POST /save-emergency-report
    Headers: {"X-Api-Key": "your-api-key"}
    Body: {
        "sender": "628xxx@s.whatsapp.net",
        "sender_name": "John Doe",
        "chat_id": "628xxx@s.whatsapp.net",
        "is_group": false,
        "message_text": "Ada banjir...",
        "disaster_type": "flood",
        "severity": 5
    }
    """
    import psycopg2
    from datetime import datetime

    try:
        # Database connection
        conn = psycopg2.connect(
            host=os.getenv("POSTGRES_HOST", "postgres"),
            port=int(os.getenv("POSTGRES_PORT", 5432)),
            database=os.getenv("POSTGRES_DB", "emergency_db"),
            user=os.getenv("POSTGRES_USER", "emergency"),
            password=os.getenv("POSTGRES_PASSWORD", "emergency123")
        )

        cursor = conn.cursor()

        # INSERT query - id and created_at will auto-generate
        sql = """
        INSERT INTO emergency_reports
          (sender, sender_name, chat_id, is_group, message_text, disaster_type, severity, status)
        VALUES
          (%s, %s, %s, %s, %s, %s, %s, 'pending')
        RETURNING id, sender, sender_name, disaster_type, severity, created_at
        """

        values = (
            data.get('sender', ''),
            data.get('sender_name', 'Unknown'),
            data.get('chat_id', ''),
            data.get('is_group', False),
            data.get('message_text', ''),
            data.get('disaster_type', 'other'),
            data.get('severity', 1)
        )

        cursor.execute(sql, values)
        result = cursor.fetchone()
        conn.commit()

        # Close connection
        cursor.close()
        conn.close()

        if result:
            report_id, sender, sender_name, disaster_type, severity, created_at = result

            logger.info(f"Emergency report saved: ID={report_id}, Type={disaster_type}")

            return ApiResponse(
                success=True,
                message="Emergency report saved",
                data={
                    "id": report_id,
                    "sender": sender,
                    "sender_name": sender_name,
                    "disaster_type": disaster_type,
                    "severity": severity,
                    "created_at": created_at.isoformat() if created_at else None,
                    "report_id": f"RPT-{int(datetime.now().timestamp() * 1000)}"
                }
            )
        else:
            raise Exception("Insert failed - no result returned")

    except Exception as e:
        logger.error(f"Failed to save emergency report: {e}")
        raise HTTPException(status_code=500, detail=str(e))
'''

print("=" * 60)
print("ADD ENDPOINT TO NEONIZE API")
print("=" * 60)
print("\n1. Open file: examples/n8n_bridge.py")
print("\n2. Add this code BEFORE the '# ==================== ERROR HANDLERS ====================' section:")
print("\n" + "=" * 60)
print(endpoint_code)
print("=" * 60)
print("\n3. Add psycopg2 to requirements:")
print("   pip install psycopg2-binary")
print("\n4. Restart neonize container:")
print("   docker compose -f docker-compose.emergency.yml restart emergency_neonize")
print("\n5. Update workflow to use HTTP Request node instead of Postgres node")
print("   - URL: http://emergency_neonize:8000/save-emergency-report")
print("   - Method: POST")
print("   - Body: {sender, sender_name, chat_id, is_group, message_text, disaster_type, severity}")
print("   - Auth: Header Auth with X-Api-Key")
