#!/usr/bin/env bash
# Editor launch helper shared by the local and shared frontends.

_editor_open(){
  local path="$1"
  command -v "$EDITOR_CMD" >/dev/null 2>&1 || die "editor '$EDITOR_CMD' not found"
  case "$EDITOR_CMD" in
    cursor|code|cursor.app|code-insiders)
      "$EDITOR_CMD" -n -- "$path" >/dev/null 2>&1 &
      ;;
    *)
      "$EDITOR_CMD" "$path" >/dev/null 2>&1 &
      ;;
  esac
}
