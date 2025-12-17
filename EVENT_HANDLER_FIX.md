# Event Handler Registration Bug - Critical Fix

## Problem Description

Even after fixing Docker volume mount and database path issues, the health check endpoint still reported:

```json
{
    "status": "disconnected",
    "neonize_connected": false
}
```

Despite logs showing:
- ✅ Bot successfully paired
- ✅ Bot successfully authenticated
- ✅ Login successful
- ✅ Session files created (1 file in sessions/)

## Root Cause

**Event handlers were not being registered correctly**, causing the `on_connected` callback to never fire.

### The Bug

In `examples/n8n_bridge.py`, event handlers were registered incorrectly:

```python
# ❌ WRONG - Missing event type parameter
@neonize_client.event
def on_connected(client: NewClient, event: ConnectedEv):
    global client_connected
    client_connected = True  # This never executes!
    logger.info("✅ Neonize connected to WhatsApp!")
```

### Why This Caused the Problem

1. Event decorator **requires the event type as a parameter**: `@client.event(EventType)`
2. Without the event type, the handler is not properly registered
3. `on_connected` callback never fires when connection succeeds
4. `client_connected` global variable remains `False`
5. Health check endpoint returns `"neonize_connected": false`
6. No log message "✅ Neonize connected to WhatsApp!" appears

### Evidence from Logs

**Missing from logs:**
- ❌ No "✅ Neonize connected to WhatsApp!" message
- ❌ No "bot_connected" event forwarded to n8n
- ❌ `client_connected` never set to `True`

**Present in logs:**
- ✅ "Successfully paired" (from whatsmeow, not our handler)
- ✅ "Successfully authenticated" (from whatsmeow, not our handler)
- ✅ QR code displayed correctly

## The Fix

### Correct Event Handler Registration

Updated all event handlers to include event type parameter:

```python
# ✅ CORRECT - Event type as parameter
@neonize_client.event(ConnectedEv)
def on_connected(client: NewClient, event: ConnectedEv):
    global client_connected
    client_connected = True
    logger.info("✅ Neonize connected to WhatsApp!")

@neonize_client.event(DisconnectedEv)
def on_disconnected(client: NewClient, event: DisconnectedEv):
    global client_connected
    client_connected = False
    logger.warning("⚠️ Neonize disconnected!")

@neonize_client.event(MessageEv)
def on_message(client: NewClient, event: MessageEv):
    # Handle incoming messages
    pass

@neonize_client.event(ReceiptEv)
def on_receipt(client: NewClient, event: ReceiptEv):
    # Handle message receipts
    pass
```

### Files Changed

1. **examples/n8n_bridge.py**:
   - Fixed `@neonize_client.event` → `@neonize_client.event(ConnectedEv)`
   - Fixed `@neonize_client.event` → `@neonize_client.event(DisconnectedEv)`
   - Fixed `@neonize_client.event` → `@neonize_client.event(MessageEv)`
   - Fixed `@neonize_client.event` → `@neonize_client.event(ReceiptEv)`

2. **examples/emergency_response_bot.py**:
   - Fixed `@self.client.event` → `@self.client.event(ConnectedEv)`
   - Fixed `@self.client.event` → `@self.client.event(DisconnectedEv)`
   - Fixed `@self.client.event` → `@self.client.event(MessageEv)`

## How to Apply the Fix

### For Existing Installations

```bash
cd ~/neonize-emergency

# Download and run the rebuild script (already includes this fix)
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/rebuild-neonize.sh -o rebuild-neonize.sh
chmod +x rebuild-neonize.sh
./rebuild-neonize.sh
```

The rebuild script will download the corrected `n8n_bridge.py` with proper event handler registration.

## Verification After Fix

### 1. Check Logs for Connection Message

```bash
docker logs emergency_neonize | grep "Neonize connected"
```

**Should show:**
```
✅ Neonize connected to WhatsApp!
```

### 2. Health Check Endpoint

```bash
curl http://localhost:8000/health | python3 -m json.tool
```

**Should show:**
```json
{
    "status": "healthy",
    "neonize_connected": true,
    "timestamp": "2025-12-17T...",
    "session": "emergency_bot"
}
```

### 3. Test Message Handling

Send a test message to your WhatsApp bot number. The bot should:
- ✅ Receive the message
- ✅ Process it through event handler
- ✅ Forward to n8n webhook
- ✅ Log "Message forwarded to n8n: {message_id}"

### 4. Persistence Test

```bash
# Restart container
docker restart emergency_neonize

# Wait 10 seconds
sleep 10

# Check logs - should show reconnection without QR code
docker logs emergency_neonize --tail 20

# Should see:
# ✅ Neonize connected to WhatsApp!
# (NOT a QR code)
```

## Reference: Correct Pattern from Neonize Examples

From `examples/basic.py`:

```python
from neonize.client import NewClient
from neonize.events import ConnectedEv, MessageEv, ReceiptEv

client = NewClient("db.sqlite3")

@client.event(ConnectedEv)
def on_connected(_: NewClient, __: ConnectedEv):
    log.info("⚡ Connected")

@client.event(MessageEv)
def on_message(client: NewClient, message: MessageEv):
    handler(client, message)

@client.event(ReceiptEv)
def on_receipt(_: NewClient, receipt: ReceiptEv):
    log.debug(receipt)

client.connect()
```

**Key points:**
- ✅ Event type passed to decorator: `@client.event(EventType)`
- ✅ Handler function takes client and event as parameters
- ✅ Event handlers registered BEFORE calling `client.connect()`

## Summary of All Three Issues

| Issue | Symptom | Root Cause | Status |
|-------|---------|------------|--------|
| #1: Docker Volume | Sessions directory empty | Named volume instead of bind mount | ✅ Fixed |
| #2: Database Path | Sessions not persisting | Database created outside mounted directory | ✅ Fixed |
| #3: Event Handlers | Health check shows disconnected | Event decorator missing event type parameter | ✅ Fixed |

**All three fixes are required for full functionality:**

1. ✅ Docker bind mount → Sessions visible on host
2. ✅ Database in sessions/ → Sessions persist correctly
3. ✅ Event handlers registered → Health check reports connected

## Impact

After this fix:
- ✅ `client_connected` properly set to `True` on connection
- ✅ Health endpoint returns `"neonize_connected": true`
- ✅ Connection events forwarded to n8n webhook
- ✅ Message events properly handled and forwarded
- ✅ Bot fully functional and responsive

---

**Created**: 2025-12-17
**Issue**: Event handlers not registered correctly
**Fix**: Add event type parameter to all `@client.event()` decorators
**Files**: examples/n8n_bridge.py, examples/emergency_response_bot.py
