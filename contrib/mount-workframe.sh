#!/bin/bash
# Mount a box-hosted workframe SMB share (idempotent).
#
# Credentials come from the login keychain (or a one-shot seed file). Connection
# details come from the environment, or from ~/workframe/config when present:
#   WORKFRAME_SHARE_NAME / share_name
#   WORKFRAME_BOX_USER   / box_user
#   WORKFRAME_MOUNT_PATH / mount_path
#   WORKFRAME_BOX_ADDR   / box_addr  (or WORKFRAME_BOX_HOST / box_host)
#
# There are no baked-in hosts or fleet IPs — set env vars or run `workframe init --shared`.

_cfg="${HOME}/workframe/config"
_get() {
  local key="$1" envv="$2" val=""
  if [ -n "${!envv:-}" ]; then printf '%s' "${!envv}"; return; fi
  if [ -f "$_cfg" ]; then
    val=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$_cfg" | head -1)
    val=${val%"${val##*[![:space:]]}"}
  fi
  printf '%s' "$val"
}

SHARE="$(_get share_name WORKFRAME_SHARE_NAME)"
SMBUSER="$(_get box_user WORKFRAME_BOX_USER)"
MP="$(_get mount_path WORKFRAME_MOUNT_PATH)"
SERVER="$(_get box_addr WORKFRAME_BOX_ADDR)"
[ -z "$SERVER" ] && SERVER="$(_get box_host WORKFRAME_BOX_HOST)"
SEED="${HOME}/.workframe-cred.seed"

if [ -z "$SHARE" ] || [ -z "$SMBUSER" ] || [ -z "$MP" ] || [ -z "$SERVER" ]; then
  echo "$(date): mount-workframe: set WORKFRAME_SHARE_NAME, WORKFRAME_BOX_USER, WORKFRAME_MOUNT_PATH, WORKFRAME_BOX_ADDR (or fill ~/workframe/config via workframe init --shared)"
  exit 1
fi

if /sbin/mount | grep -q " on ${MP} "; then exit 0; fi

# Prefer keychain; else seed file (first-run / headless).
P=$(/usr/bin/security find-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " -w 2>/dev/null || true)
if [ -z "$P" ] && [ -f "$SEED" ]; then
  P=$(cat "$SEED")
  /usr/bin/security add-internet-password -a "$SMBUSER" -s "$SERVER" -r "smb " -l "workframe SMB" -w "$P" -T /sbin/mount_smbfs -U 2>/dev/null && rm -f "$SEED" || true
fi
[ -z "$P" ] && { echo "$(date): no keychain/seed cred for ${SMBUSER}@${SERVER}"; exit 1; }

_urlencode() {
  local s=$1 i c
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) printf '%s' "$c";;
      *) printf '%%%02X' "'$c";;
    esac
  done
}
_applescript_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

ENC_USER=$(_urlencode "$SMBUSER")
ENC_PASS=$(_urlencode "$P")
ENC_SHARE=$(_urlencode "$SHARE")
AS_URL=$(_applescript_escape "smb://${ENC_USER}:${ENC_PASS}@${SERVER}/${ENC_SHARE}")

for i in $(seq 1 20); do /usr/bin/nc -z -G 2 "$SERVER" 445 2>/dev/null && break; sleep 1; done

mkdir -p "$MP" 2>/dev/null || true
if /sbin/mount_smbfs "//${ENC_USER}:${ENC_PASS}@${SERVER}/${ENC_SHARE}" "$MP" 2>/dev/null; then
  :
else
  /usr/bin/osascript -e "mount volume \"${AS_URL}\"" >/dev/null 2>&1 || true
fi

if /sbin/mount | grep -q " on ${MP} "; then echo "$(date): mounted ${MP}"; exit 0; fi
# osascript may mount under /Volumes/<Share> from the share name
if [ -d "/Volumes/${SHARE}" ] && /sbin/mount | grep -q " on /Volumes/${SHARE} "; then
  echo "$(date): mounted /Volumes/${SHARE}"
  exit 0
fi
echo "$(date): mount failed"; exit 1
