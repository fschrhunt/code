#!/usr/bin/env bash
# Regenerate the two Workframe mark variants from the canonical geometry.
set -euo pipefail

cd "$(dirname "$0")"

write_mark(){
  local output=$1 color=$2
  cat > "$output" <<EOF
<svg width="751" height="601" viewBox="0 0 751 601" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="title">
  <title id="title">Workframe</title>
  <path fill-rule="evenodd" clip-rule="evenodd" d="M750.221 0H0V600.221H750.221V0ZM600.221 150H150.221V450.221L600.221 450V150Z" fill="$color"/>
</svg>
EOF
}

write_mark logo.svg '#09090B'
write_mark logo-white.svg '#FFFFFF'
