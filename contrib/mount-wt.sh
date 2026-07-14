#!/bin/bash
# Mount the box-hosted wt share (idempotent). Prefer this over mount-agents.sh.
# Paths come from the environment or match wt shared-profile defaults.
# Legacy: SHARE=Agents MP=/Volumes/Agents still works if you set them.
SHARE="${WT_SHARE_NAME:-wt}"
SMBUSER="${WT_BOX_USER:-agents}"
MP="${WT_MOUNT_PATH:-/Volumes/wt}"
SERVER="${WT_BOX_ADDR:-100.65.233.79}"
SEED="$HOME/.wt-cred.seed"

if /sbin/mount | grep -q " on ${MP} "; then exit 0; fi

if [ -f "$SEED" ] && ! /usr/bin/security find-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " >/dev/null 2>&1; then
  /usr/bin/security add-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " -l "wt SMB (box)" -w "$(cat "$SEED")" -T /sbin/mount_smbfs -U 2>/dev/null && rm -f "$SEED"
fi

for i in $(seq 1 20); do /usr/bin/nc -z -G 2 "$SERVER" 445 2>/dev/null && break; sleep 1; done

P=$(/usr/bin/security find-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " -w 2>/dev/null)
[ -z "$P" ] && { echo "$(date): no keychain cred for ${SMBUSER}@${SERVER}"; exit 1; }

/usr/bin/osascript -e "mount volume \"smb://${SMBUSER}:${P}@${SERVER}/${SHARE}\"" >/dev/null 2>&1
if /sbin/mount | grep -q " on ${MP} "; then echo "$(date): mounted ${MP}"; exit 0; fi
echo "$(date): mount failed"; exit 1
