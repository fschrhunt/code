#!/usr/bin/env bash
# build — regenerate every Workframe brand asset from one source of truth.
#
# All SVGs are derived from the master lockup geometry below, so the mark, the
# wordmark and the full lockup can never drift apart. PNG exports are optional
# and are skipped when rsvg-convert is unavailable.
#
# Usage: assets/build.sh
set -euo pipefail

cd "$(dirname "$0")"

# --- brand ------------------------------------------------------------------
ACID="#F0FB29"
INK="#202020"
WHITE="#FFFFFF"

# --- master geometry --------------------------------------------------------
# Source artwork is 713x218 with rx=30. Content boxes inside it:
#   mark      x 326..398   y  30..84    (72 x 54)
#   wordmark  x  73..641   y 129..187   (568 x 58)
#   lockup    x  73..641   y  30..187   (568 x 157)
# Every derived file re-frames those boxes with a transform, never by editing
# path data.
MARK_OX=326; MARK_OY=30;  MARK_W=72;  MARK_H=54
WORD_OX=73;  WORD_OY=129; WORD_W=568; WORD_H=58
LOCK_OX=73;  LOCK_OY=30;  LOCK_W=568; LOCK_H=157

mark_paths() {
  cat <<'EOF'
    <path d="M390 84H380V75H389V67H380V47H389V39H380V30H390V38H398V48H390V66H398V76H390V84Z"/>
    <path d="M353 75H371V84H353V75Z"/>
    <path d="M371 30V39H353V30H371Z"/>
    <path d="M334 84H344V75H335V67H344V47H335V39H344V30H334V38H326V48H334V66H326V76H334V84Z"/>
EOF
}

wordmark_paths() {
  cat <<'EOF'
    <path d="M73 129H82V177H98V129H107V177H123V129H132V178H124V187H106V178H99V187H81V178H73V129Z"/>
    <path d="M154 187V177H188V187H154Z"/>
    <path d="M154 139V129H188V139H154Z"/>
    <path d="M155 138H146V178H155V138Z"/>
    <path d="M196 138H187V178H196V138Z"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M210 129H219H253V137H261V154H253V161H261V187H252V162H219V187H210V129ZM219 153H252V138H219V153Z"/>
    <path d="M284 129H275V187H284V162H309V170H317V187H326V169H318V161H310V154H318V146H326V129H317V145H309V153H284V129Z"/>
    <path d="M348.025 187H340V161H348.025V154H340V137H348.025V129H381V138H348.025V153H381V162H348.025V187Z"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M396 129H405H439V137H447V154H439V161H447V187H438V162H405V187H396V129ZM405 153H438V138H405V153Z"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M470 187H461V137H469V129H504V137H512V187H503V162H470V187ZM470 153H503V138H470V153Z"/>
    <path d="M585 187H576V139H560V187H551V139H535V187H526V138H534V129H552V138H559V129H577V138H585V187Z"/>
    <path d="M600 154V137H608.025V129H641V138H608.025V153H641V162H608.025V178H641V187H608.025V179H600V161H608.025V154H600Z"/>
EOF
}

lockup_paths() { mark_paths; wordmark_paths; }

# --- emitters ---------------------------------------------------------------
# svg_open <width> <height> <title>
svg_open() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s" fill="none" role="img">\n' \
    "$1" "$2" "$1" "$2"
  printf '  <title>%s</title>\n' "$3"
}

# tile <size> <radius> <fill>
tile() { printf '  <rect width="%s" height="%s" rx="%s" fill="%s"/>\n' "$1" "$1" "$2" "$3"; }

# group <fill> <transform> <paths-fn>
group() {
  printf '  <g fill="%s" transform="%s">\n' "$1" "$2"
  "$3"
  printf '  </g>\n'
}

svg_close() { printf '</svg>\n'; }

# flat <out> <title> <ox> <oy> <w> <h> <fill> <paths-fn>
flat() {
  local out=$1 title=$2 ox=$3 oy=$4 w=$5 h=$6 fill=$7 fn=$8
  { svg_open "$w" "$h" "$title"
    group "$fill" "translate($((-ox)) $((-oy)))" "$fn"
    svg_close
  } >"$out"
  echo "  $out"
}

# Output folders — assets are grouped by what they are, not by file format, so
# each folder holds its own SVGs and PNG exports side by side.
rm -rf logo wordmark lockup
mkdir -p logo wordmark lockup colors

# --- 1. mark ----------------------------------------------------------------
flat logo/logo.acid.svg  "Workframe mark" "$MARK_OX" "$MARK_OY" "$MARK_W" "$MARK_H" "$ACID"  mark_paths
flat logo/logo.black.svg "Workframe mark" "$MARK_OX" "$MARK_OY" "$MARK_W" "$MARK_H" "$INK"   mark_paths
flat logo/logo.white.svg "Workframe mark" "$MARK_OX" "$MARK_OY" "$MARK_W" "$MARK_H" "$WHITE" mark_paths

# Tiled app icons. One geometry for every icon, drawn on a 1024 box:
#   corner radius 160 (15.6%)
#   mark 829.333 wide (81%) at (97, 201) — scale 11.5185 off the source mark
# The mark runs nearly edge to edge, which is what keeps its strokes (~1/9 of
# its width) above 1px when the icon is rasterised down to favicon sizes.
ICON_BOX=1024
ICON_RX=160
ICON_TX=97
ICON_TY=201
ICON_SCALE=11.5185185

tiled_mark() { # <out> <bg> <fg>
  { svg_open "$ICON_BOX" "$ICON_BOX" "Workframe icon"
    tile "$ICON_BOX" "$ICON_RX" "$2"
    group "$3" \
      "translate($ICON_TX $ICON_TY) scale($ICON_SCALE) translate($((-MARK_OX)) $((-MARK_OY)))" \
      mark_paths
    svg_close
  } >"$1"
  echo "  $1"
}
tiled_mark logo/logo.black-on-acid.svg  "$ACID" "$INK"
tiled_mark logo/logo.acid-on-black.svg  "$INK"  "$ACID"
tiled_mark logo/logo.white-on-black.svg "$INK"  "$WHITE"

# --- 2. wordmark ------------------------------------------------------------
flat wordmark/wordmark.acid.svg  "Workframe" "$WORD_OX" "$WORD_OY" "$WORD_W" "$WORD_H" "$ACID"  wordmark_paths
flat wordmark/wordmark.black.svg "Workframe" "$WORD_OX" "$WORD_OY" "$WORD_W" "$WORD_H" "$INK"   wordmark_paths
flat wordmark/wordmark.white.svg "Workframe" "$WORD_OX" "$WORD_OY" "$WORD_W" "$WORD_H" "$WHITE" wordmark_paths

# --- 3. lockup --------------------------------------------------------------
flat lockup/lockup.acid.svg  "Workframe" "$LOCK_OX" "$LOCK_OY" "$LOCK_W" "$LOCK_H" "$ACID"  lockup_paths
flat lockup/lockup.black.svg "Workframe" "$LOCK_OX" "$LOCK_OY" "$LOCK_W" "$LOCK_H" "$INK"   lockup_paths
flat lockup/lockup.white.svg "Workframe" "$LOCK_OX" "$LOCK_OY" "$LOCK_W" "$LOCK_H" "$WHITE" lockup_paths

# Boxed lockups keep the original 713x218 / rx 30 framing.
boxed_lockup() { # <out> <bg> <fg>
  { svg_open 713 218 "Workframe"
    printf '  <rect width="713" height="218" rx="30" fill="%s"/>\n' "$2"
    group "$3" "translate(0 0)" lockup_paths
    svg_close
  } >"$1"
  echo "  $1"
}
boxed_lockup lockup/lockup.black-on-acid.svg  "$ACID" "$INK"
boxed_lockup lockup/lockup.acid-on-black.svg  "$INK"  "$ACID"
boxed_lockup lockup/lockup.white-on-black.svg "$INK"  "$WHITE"

# --- 4. primary icon --------------------------------------------------------
# The drop-in icon, parked at the top of assets/ next to this script so it is
# the obvious thing to grab. Identical geometry to logo/logo.black-on-acid.svg.
# It doubles as the favicon: the mark runs to 81%, which keeps its strokes above
# 1px down to 16px, so no separate favicon sizes are needed.
tiled_mark logo.svg "$ACID" "$INK"

# --- 5. png exports ---------------------------------------------------------
# Each export lands next to the SVG it came from.
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "  (rsvg-convert not found — skipping PNG exports)"
  exit 0
fi

png() { # <src.svg> <width> <out.png>
  rsvg-convert -w "$2" "$1" -o "$3"
  echo "  $3"
}
png logo/logo.black-on-acid.svg 1024 logo/logo.black-on-acid.1024.png
png logo/logo.black-on-acid.svg  512 logo/logo.black-on-acid.512.png
png logo/logo.black-on-acid.svg  256 logo/logo.black-on-acid.256.png
png logo/logo.acid-on-black.svg  512 logo/logo.acid-on-black.512.png
png logo/logo.acid.svg           512 logo/logo.acid.512.png
png logo/logo.black.svg          512 logo/logo.black.512.png
png logo/logo.white.svg          512 logo/logo.white.512.png

png lockup/lockup.black.svg          1136 lockup/lockup.black@2x.png
png lockup/lockup.white.svg          1136 lockup/lockup.white@2x.png
png lockup/lockup.acid.svg           1136 lockup/lockup.acid@2x.png
png lockup/lockup.black-on-acid.svg  1426 lockup/lockup.black-on-acid@2x.png

png logo.svg 1024 logo.png
