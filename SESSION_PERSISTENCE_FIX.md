# Session Persistence Issue - Root Cause & Fix

## Problem Description

After installation, the Neonize bot would successfully pair and authenticate with WhatsApp (logs show "Successfully paired", "Successfully authenticated", "Login event: success"), but:

1. ❌ Session files were NOT being saved to the host filesystem
2. ❌ `~/neonize-emergency/sessions/` directory remained empty (0 files)
3. ❌ Health check persistently showed `"neonize_connected": false`
4. ❌ After container restart, bot required re-scanning QR code (session lost)

## Root Cause Analysis

### Two Separate Issues Found

#### Issue #1: Docker Volume Configuration (FIXED)

In `docker-compose.emergency.yml`, the neonize_bridge service volume was configured as:

```yaml
volumes:
  - neonize_sessions:/app/sessions  # ❌ WRONG: Named volume
```

This is a **Docker named volume** (defined in the `volumes:` section at the bottom), which stores data in Docker's internal storage at `/var/lib/docker/volumes/neonize_sessions/`.

**The problem:**
- ✅ Container writes session files to `/app/sessions` (inside container)
- ✅ Docker stores them in the named volume
- ❌ But NOT visible on host at `~/neonize-emergency/sessions/`
- ❌ Host directory exists but remains empty
- ❌ User cannot see or backup session files

### Why This Matters

1. **Session Loss**: When named volume is deleted or container recreated, sessions may be lost
2. **No Visibility**: User cannot see or backup session files from host
3. **Debugging Difficulty**: Cannot easily check if sessions are being created
4. **Portability**: Cannot easily move sessions between environments

**Status**: ✅ Fixed in docker-compose.emergency.yml

#### Issue #2: Database Path in Application Code (FIXED)

Even after fixing the Docker volume mount, session files were still not appearing because **the database was being created in the wrong location inside the container**.

In `examples/n8n_bridge.py`, the NewClient was initialized incorrectly:

```python
# ❌ WRONG - Creates database at /app/emergency_bot
SESSION_NAME = os.getenv("SESSION_NAME", "emergency_bot")
neonize_client = NewClient(SESSION_NAME)
```

**The problem:**
- `NewClient(name)` treats the first parameter as the **database path**, not just a session name
- Database file created at `/app/emergency_bot` (root of container)
- NOT inside `/app/sessions/` (which is bind-mounted to host)
- Result: Session data stored in container's ephemeral filesystem
- After container restart: Sessions lost, QR code required again

**Status**: ✅ Fixed in examples/n8n_bridge.py and examples/emergency_response_bot.py

## The Fix

### Fix #1: Change from Named Volume to Bind Mount

Updated `docker-compose.emergency.yml`:

```yaml
volumes:
  - ./sessions:/app/sessions  # ✅ CORRECT: Bind mount to host directory
```

This creates a **bind mount** that directly maps the container's `/app/sessions` to the host's `~/neonize-emergency/sessions/` directory.

**Benefits:**
- ✅ Session files immediately visible on host
- ✅ Easy to backup: just copy `sessions/` directory
- ✅ Survives container recreation
- ✅ Can inspect files directly from host
- ✅ Better for development and troubleshooting

### Fix #2: Update Application to Store Database in Sessions Directory

Updated `examples/n8n_bridge.py`:

```python
# ✅ CORRECT - Creates database at /app/sessions/emergency_bot.db
def setup_neonize_client():
    global neonize_client, client_connected

    logger.info("Initializing Neonize client...")

    # Create sessions directory if it doesn't exist
    os.makedirs("sessions", exist_ok=True)

    # Store database in sessions directory for persistence
    database_path = f"sessions/{SESSION_NAME}.db"
    logger.info(f"Using database: {database_path}")

    neonize_client = NewClient(database_path)
```

**Benefits:**
- ✅ Database stored inside `/app/sessions/` directory
- ✅ Bind mount makes it visible on host at `~/neonize-emergency/sessions/`
- ✅ Sessions persist across container restarts
- ✅ Can see session files: `emergency_bot.db`, `emergency_bot.db-shm`, `emergency_bot.db-wal`

### What Was Changed

1. **docker-compose.emergency.yml**:
   - Changed volume mount from `neonize_sessions:/app/sessions` to `./sessions:/app/sessions`
   - Removed `neonize_sessions` from volumes section

2. **examples/n8n_bridge.py**:
   - Updated `setup_neonize_client()` to create database in `sessions/` directory
   - Added `os.makedirs("sessions", exist_ok=True)` to ensure directory exists
   - Changed from `NewClient(SESSION_NAME)` to `NewClient(f"sessions/{SESSION_NAME}.db")`
   - Added logging to show database path

3. **examples/emergency_response_bot.py**:
   - Updated `__init__()` to use same pattern as n8n_bridge.py
   - Database now stored in `sessions/` directory
   - Added `import os` for directory creation

4. **diagnose.sh** (enhanced):
   - Added volume mount type detection
   - Checks if using bind mount vs named volume
   - Compares host vs container session files
   - Provides specific fix recommendation

5. **fix-sessions.sh** (new script):
   - Backs up any existing sessions from Docker volume to host
   - Updates docker-compose configuration
   - Restarts services with correct configuration
   - Verifies the fix

6. **rebuild-neonize.sh** (new script):
   - Downloads updated n8n_bridge.py with database path fix
   - Rebuilds Docker image with updated code
   - Clears old sessions and restarts container
   - Verifies database is created in correct location

## How to Apply the Fix

### For Existing Installations

⚠️ **IMPORTANT**: Both fixes are required for sessions to persist correctly!

#### Step 1: Fix Docker Volume Mount

```bash
cd ~/neonize-emergency

# Download and run the volume fix script
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/fix-sessions.sh -o fix-sessions.sh
chmod +x fix-sessions.sh
./fix-sessions.sh
```

This fixes the Docker volume configuration (named volume → bind mount).

#### Step 2: Rebuild Container with Database Path Fix

```bash
cd ~/neonize-emergency

# Download and run the rebuild script
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/rebuild-neonize.sh -o rebuild-neonize.sh
chmod +x rebuild-neonize.sh
./rebuild-neonize.sh
```

This script will:
1. ✅ Download updated n8n_bridge.py with correct database path
2. ✅ Rebuild Docker image with the fix
3. ✅ Restart container (you'll need to scan QR code again)
4. ✅ Verify session files are created in the correct location

#### Combined Quick Fix

Run both fixes in sequence:

```bash
cd ~/neonize-emergency

# Fix 1: Volume mount
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/fix-sessions.sh | bash

# Fix 2: Rebuild with database path fix
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/rebuild-neonize.sh | bash
```

### For New Installations

The updated `install.sh` and `fix-install.sh` scripts now download the corrected `docker-compose.emergency.yml` that uses bind mount by default.

New installations will automatically use the correct configuration.

## Verification

After applying the fix, verify it's working:

### 1. Run Diagnostic

```bash
./diagnose.sh
```

Look for:
```
✓ Using bind mount (CORRECT - sessions persist to host)
```

### 2. Check Session Files on Host

```bash
ls -la ~/neonize-emergency/sessions/
```

After pairing, should see files like:
- `store.db` or `session.dat`
- `device.json`
- Other neonize session files

### 3. Test Persistence

```bash
# Restart container
docker restart emergency_neonize

# Check logs - should NOT show QR code
docker logs emergency_neonize -f

# If sessions persisted correctly:
# ✅ No QR code shown
# ✅ Bot reconnects automatically
# ✅ Logs show "Connected" without requiring re-pairing
```

### 4. Check Health Endpoint

```bash
curl http://localhost:8000/health | jq
```

Should eventually show:
```json
{
  "status": "healthy",
  "neonize_connected": true,
  ...
}
```

## Understanding Docker Volumes

### Named Volume vs Bind Mount

| Feature | Named Volume | Bind Mount |
|---------|--------------|------------|
| Definition | `volume_name:/path` | `./local_path:/path` |
| Storage Location | `/var/lib/docker/volumes/` | User-specified host path |
| Visibility | Not visible on host | Fully visible on host |
| Best For | Database data, internal state | Config files, sessions, development |
| Backup | `docker cp` or volume backup | Standard file copy |
| Portability | Docker-managed | Host filesystem |

### When to Use Each

**Use Named Volumes for:**
- Database data (PostgreSQL, Redis)
- Internal application state
- Performance-critical operations
- Production deployments with Docker-managed backup

**Use Bind Mounts for:**
- Session files (like WhatsApp sessions)
- Configuration files
- Logs (for easy access)
- Development environments
- Files that need frequent inspection

## Technical Details

### How Neonize Stores Sessions

The neonize library (based on whatsmeow) stores WhatsApp session data in files:

1. **Device Keys**: Cryptographic keys for device identity
2. **Session Store**: Authentication tokens and session state
3. **App State**: Synchronized application state from WhatsApp

These files are critical for:
- Avoiding re-authentication on restart
- Maintaining device identity
- Syncing message history

### Volume Mount in docker-compose.yml

**Before (incorrect):**
```yaml
services:
  neonize_bridge:
    volumes:
      - neonize_sessions:/app/sessions  # Named volume
volumes:
  neonize_sessions:
    driver: local
```

**After (correct):**
```yaml
services:
  neonize_bridge:
    volumes:
      - ./sessions:/app/sessions  # Bind mount to host
# No volume definition needed
```

### File Permissions

The bind mount requires proper permissions:

```bash
mkdir -p ~/neonize-emergency/sessions
chmod 777 ~/neonize-emergency/sessions  # Allow container write access
```

Or more secure:
```bash
chown 1000:1000 ~/neonize-emergency/sessions  # Match container user
chmod 755 ~/neonize-emergency/sessions
```

## Troubleshooting

### Issue: "Sessions still empty after fix"

**Check:**
1. Volume mount type: `docker inspect emergency_neonize | grep -A 10 Mounts`
2. Inside container: `docker exec emergency_neonize ls -la /app/sessions`
3. Container logs: `docker logs emergency_neonize`

**Solution:**
- Ensure QR code was scanned after applying fix
- Wait 10-30 seconds after pairing for files to be written
- Check container has write permission

### Issue: "Permission denied writing to sessions"

**Check:**
```bash
ls -ld ~/neonize-emergency/sessions/
# Should be writable by container user
```

**Solution:**
```bash
chmod 777 ~/neonize-emergency/sessions/
# Or match container user:
chown 1000:1000 ~/neonize-emergency/sessions/
```

### Issue: "Fix script fails"

**Check:**
1. Docker permission: `docker ps` (should work without sudo)
2. Directory exists: `ls ~/neonize-emergency/`
3. Container running: `docker ps | grep emergency_neonize`

**Solution:**
```bash
# Fix docker permission
newgrp docker

# Create directory if missing
mkdir -p ~/neonize-emergency/sessions
```

## Prevention

For future Docker services with persistent state:

1. **Evaluate Storage Needs**: Does the user need to see/backup these files?
2. **Choose Appropriate Mount**:
   - User-facing data → Bind mount
   - Internal state → Named volume
3. **Document Clearly**: Explain in docker-compose.yml comments
4. **Test Persistence**: Verify files appear where expected
5. **Provide Diagnostics**: Include tools to check configuration

## Summary

**Problem**: Session files stored in Docker named volume, not accessible on host
**Solution**: Changed to bind mount for direct host filesystem access
**Result**: Session files now persist correctly and are visible on host
**Status**: ✅ Fixed in all installation scripts and docker-compose.yml

---

**Created**: 2025-12-17
**Issue**: Session persistence failure after installation
**Fix**: Change Docker named volume to bind mount for sessions directory
**Impact**: All neonize-emergency installations
