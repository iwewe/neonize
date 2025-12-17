# Session Persistence Issue - Root Cause & Fix

## Problem Description

After installation, the Neonize bot would successfully pair and authenticate with WhatsApp (logs show "Successfully paired", "Successfully authenticated", "Login event: success"), but:

1. ❌ Session files were NOT being saved to the host filesystem
2. ❌ `~/neonize-emergency/sessions/` directory remained empty (0 files)
3. ❌ Health check persistently showed `"neonize_connected": false`
4. ❌ After container restart, bot required re-scanning QR code (session lost)

## Root Cause Analysis

### The Issue

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

## The Fix

### Change from Named Volume to Bind Mount

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

### What Was Changed

1. **docker-compose.emergency.yml**:
   - Changed volume mount from `neonize_sessions:/app/sessions` to `./sessions:/app/sessions`
   - Removed `neonize_sessions` from volumes section

2. **diagnose.sh** (enhanced):
   - Added volume mount type detection
   - Checks if using bind mount vs named volume
   - Compares host vs container session files
   - Provides specific fix recommendation

3. **fix-sessions.sh** (new script):
   - Backs up any existing sessions from Docker volume to host
   - Updates docker-compose configuration
   - Restarts services with correct configuration
   - Verifies the fix

## How to Apply the Fix

### For Existing Installations

If you already have neonize-emergency installed and experiencing this issue:

```bash
cd ~/neonize-emergency

# Download the fix script
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/fix-sessions.sh -o fix-sessions.sh
chmod +x fix-sessions.sh

# Run the fix
./fix-sessions.sh
```

The script will:
1. ✅ Check current configuration
2. ✅ Copy any existing sessions from Docker volume to host
3. ✅ Update docker-compose.yml to use bind mount
4. ✅ Restart services with new configuration
5. ✅ Verify the fix was successful

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
