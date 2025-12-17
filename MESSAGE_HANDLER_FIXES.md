# Message Handler Fixes - Bug #4 & #5

## Status: ✅ RESOLVED

**Previous Status:**
- ✅ Issue #1: Docker volume mount (FIXED)
- ✅ Issue #2: Database path (FIXED)
- ✅ Issue #3: Event handlers (FIXED)
- ✅ Health check shows: `"neonize_connected": true"`

**New Issues Found:**
After event handlers were fixed and bot started receiving messages, two new bugs appeared.

## Bug #4: AttributeError on PushName

### Error
```python
AttributeError: PushName
File "/app/n8n_bridge.py", line 237, in on_message
    push_name = event.Info.PushName or "Unknown"
                ^^^^^^^^^^^^^^^^^^^
```

### Root Cause
`PushName` is an optional field in the protobuf message. Not all WhatsApp messages include a PushName (e.g., automated messages, system messages). Direct attribute access fails when the field is not present.

### Fix
Use safe attribute access with `getattr()`:

```python
# ❌ BEFORE - Direct access (crashes if not present)
push_name = event.Info.PushName or "Unknown"

# ✅ AFTER - Safe access with default
push_name = getattr(event.Info, 'PushName', 'Unknown')
```

## Bug #5: JSON Serialization Error

### Error
```
Object of type RepeatedScalarContainer is not JSON serializable
```

### Root Cause
Protobuf objects cannot be directly serialized to JSON:
- `sender` and `chat` are JID (Jabber ID) protobuf objects
- `timestamp` is a datetime object
- `event.MessageIDs` is a RepeatedScalarContainer (protobuf list)

When trying to forward these to n8n webhook via `httpx.AsyncClient().post(json=payload)`, JSON serialization fails.

### Fix
Convert all protobuf objects to JSON-safe types:

```python
# ❌ BEFORE - Protobuf objects (not JSON serializable)
message_data = {
    "sender": sender,              # JID object
    "chat": chat,                   # JID object
    "timestamp": timestamp,         # datetime object
}

# In receipt handler:
"message_ids": event.MessageIDs,  # RepeatedScalarContainer

# ✅ AFTER - Convert to JSON-safe types
message_data = {
    "sender": str(sender),          # String
    "chat": str(chat),              # String
    "timestamp": str(timestamp),    # ISO string
}

# In receipt handler:
"message_ids": list(event.MessageIDs),  # List
```

## Files Changed

### 1. examples/n8n_bridge.py

**PushName fix:**
```python
# Line 237
push_name = getattr(event.Info, 'PushName', 'Unknown')
```

**JSON serialization fixes:**
```python
# Lines 243-254
message_data = {
    "event_id": f"msg_{message_id}",
    "message_id": message_id,
    "sender": str(sender),          # ✅ Convert JID to string
    "sender_name": push_name,
    "chat": str(chat),              # ✅ Convert JID to string
    "is_group": is_group,
    "timestamp": str(timestamp),    # ✅ Convert datetime to string
    "text": None,
    "media_type": None,
    "location": None
}

# Lines 289-297 (receipt handler)
asyncio.run(forward_to_n8n("receipt", {
    "type": str(event.Type),
    "message_ids": list(event.MessageIDs),  # ✅ Convert RepeatedScalarContainer to list
    "timestamp": datetime.now().isoformat(),
    "sender": str(event.MessageSource.Sender) if event.MessageSource else None  # ✅ Convert JID
}))
```

### 2. examples/emergency_response_bot.py

**Consistent fixes:**
```python
# Lines 379-392
report_data = {
    'report_id': report_id,
    'reporter': str(sender),                              # ✅ Convert JID to string
    'reporter_name': getattr(event.Info, 'PushName', 'Unknown'),  # ✅ Safe access
    'timestamp': datetime.now().isoformat(),
    'message': text,
    'category': category,
    'severity': severity,
    'location': None,
    'media': [],
    'status': 'PENDING',
    'is_group': event.Info.MessageSource.IsGroup,
    'chat': str(chat)                                     # ✅ Convert JID to string
}
```

### 3. rebuild-neonize.sh

Added documentation for normal warnings:
```bash
echo -e "${YELLOW}⚠ Normal warnings in logs:${NC}"
echo "  - 'n8n webhook returned 404' - This is normal, n8n workflow not configured yet"
echo "  - 'Got 515 code, reconnecting' - Normal WhatsApp reconnection"
```

## How to Apply the Fix

```bash
cd ~/neonize-emergency

# Download and run rebuild script (includes all fixes)
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/rebuild-neonize.sh -o rebuild-neonize.sh
chmod +x rebuild-neonize.sh
./rebuild-neonize.sh
```

## Verification After Fix

### 1. No More AttributeError
Send a message to your bot. Check logs:
```bash
docker logs emergency_neonize --tail 50
```

**Should NOT see:**
```
❌ AttributeError: PushName
```

**Should see:**
```
✅ Message forwarded to n8n: <message_id>
```

### 2. No More JSON Serialization Error
**Should NOT see:**
```
❌ ERROR - Unexpected error forwarding to n8n: Object of type RepeatedScalarContainer is not JSON serializable
```

**Should see:**
```
✅ HTTP Request: POST http://n8n:5678/webhook/emergency "HTTP/1.1 404 Not Found"
```

The 404 is **expected** - it means the message was successfully serialized and sent to n8n, but the webhook doesn't exist yet (need to create n8n workflow).

### 3. Test Message Flow

1. **Send test message** to bot's WhatsApp number
2. **Check logs:**
```bash
docker logs emergency_neonize -f
```

**Expected output:**
```
✅ Neonize connected to WhatsApp!
INFO: HTTP Request: POST http://n8n:5678/webhook/emergency "HTTP/1.1 404 Not Found"
WARNING: n8n webhook returned 404
INFO: Message forwarded to n8n: <message_id>
```

3. **Verify health check:**
```bash
curl http://localhost:8000/health | python3 -m json.tool
```

**Expected:**
```json
{
    "status": "healthy",
    "neonize_connected": true,
    "timestamp": "2025-12-18T...",
    "session": "emergency_bot"
}
```

## Understanding Normal Warnings

After these fixes, you may still see these warnings - they are **NORMAL**:

### 1. n8n webhook 404
```
WARNING - n8n webhook returned 404
```
**Meaning:** Bot is working correctly, trying to forward messages to n8n, but n8n workflow doesn't exist yet.

**Solution:** Create n8n workflow with webhook trigger at `/webhook/emergency`

### 2. WhatsApp 515 reconnection
```
INFO - Got 515 code, reconnecting...
```
**Meaning:** WhatsApp server sent reconnection request. This is normal behavior.

**Action:** None needed, bot auto-reconnects.

### 3. WebSocket EOF error
```
WARNING - Error sending close to websocket: failed to close WebSocket: failed to read frame header: EOF
```
**Meaning:** Connection closed during reconnection. Normal during WhatsApp protocol handshake.

**Action:** None needed, happens during reconnection.

## Complete Fix Stack

| Issue | Description | Status |
|-------|-------------|--------|
| #1 | Docker volume (named → bind mount) | ✅ Fixed |
| #2 | Database path (outside → inside mount) | ✅ Fixed |
| #3 | Event handlers (missing event type param) | ✅ Fixed |
| #4 | PushName AttributeError | ✅ Fixed |
| #5 | JSON serialization error | ✅ Fixed |

## Summary

**Before Fixes:**
```
❌ Health check: disconnected
❌ Messages crash with AttributeError
❌ JSON serialization fails
```

**After All Fixes:**
```
✅ Health check: connected (true)
✅ Messages processed successfully
✅ Data forwarded to n8n (404 expected, workflow not created)
✅ Sessions persist across restarts
✅ No QR code after restart
```

## Next Steps (Optional)

To complete the emergency response system:

1. **Configure n8n workflow:**
   - Access: http://your-server-ip:5678
   - Create webhook trigger: `/webhook/emergency`
   - Add emergency response logic

2. **Test full flow:**
   - Send emergency message to bot
   - Verify forwarding to n8n
   - Check n8n workflow execution

3. **Monitor logs:**
```bash
# Watch bot logs
docker logs emergency_neonize -f

# Check all services
docker compose -f docker-compose.emergency.yml ps
```

---

**Created**: 2025-12-17
**Issues**: PushName AttributeError & JSON serialization errors
**Fix**: Safe attribute access & protobuf-to-JSON conversion
**Status**: ✅ All 5 issues resolved, bot fully functional
