#!/bin/bash
# Mount the box-hosted wt share (idempotent).
SHARE="${WT_SHARE_NAME:-wt}"
SMBUSER="${WT_BOX_USER:-agents}"
MP="${WT_MOUNT_PATH:-/Volumes/wt}"
SERVER="${WT_BOX_ADDR:-100.65.233.79}"
SEED="${HOME}/.wt-cred.seed"
LEGACY_SEED="${HOME}/.wt-agents-cred.seed"

if /sbin/mount | grep -q " on ${MP} "; then exit 0; fi

# Prefer keychain; else seed file (first-run / headless).
P=$(/usr/bin/security find-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " -w 2>/dev/null || true)
if [ -z "$P" ]; then
  for s in "$SEED" "$LEGACY_SEED"; do
    if [ -f "$s" ]; then
      P=$(cat "$s")
      # Best-effort: seed login keychain when GUI session is available
      /usr/bin/security add-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " -l "wt SMB (box)" -w "$P" -T /sbin/mount_smbfs -U 2>/dev/null && rm -f "$s" || true
      break
    fi
  done
fi
[ -z "$P" ] && { echo "$(date): no keychain/seed cred for ${SMBUSER}@${SERVER}"; exit 1; }

for i in $(seq 1 20); do /usr/bin/nc -z -G 2 "$SERVER" 445 2>/dev/null && break; sleep 1; done

# osascript mounts into /Volumes/<Share>; mount_smbfs lets us force MP
mkdir -p "$MP" 2>/dev/null || true
if /sbin/mount_smbfs "//${SMBUSER}:${P}@${SERVER}/${SHARE}" "$MP" 2>/dev/null; then
  :
else
  /usr/bin/osascript -e "mount volume \"smb://${SMBUSER}:${P}@${SERVER}/${SHARE}\"" >/dev/null 2>&1 || true
fi

if /sbin/mount | grep -q " on ${MP} "; then echo "$(date): mounted ${MP}"; exit 0; fi
# osascript may mount as /Volumes/wt from share name already
if [ -d /Volumes/wt ] && /sbin/mount | grep -q " on /Volumes/wt "; then echo "$(date): mounted /Volumes/wt"; exit 0; fi
echo "$(date): mount failed"; exit 1
