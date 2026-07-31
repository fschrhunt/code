#!/usr/bin/env bash
# Agent registry + editor launch helpers (shared by frontend and backend).

_is_agent(){ [ -n "$1" ] && echo " $VALID_AGENTS " | grep -qF " $1 "; }

_agent_name_ok(){
  case "$1" in ''|*[!a-z0-9._-]*) return 1;; esac
  return 0
}

_agents_configured(){
  [ -n "$(printf '%s' "$VALID_AGENTS" | tr -d '[:space:]')" ]
}

_agents_array(){
  # shellcheck disable=SC2206
  AGENTS_ARR=($VALID_AGENTS)
}

# Active worktrees for agent lifecycle checks. Frontend overrides this to use
# `_bx` in shared profile so Mac does not inspect the wrong store.
_list_agent_worktrees(){ cmd_worktrees 2>/dev/null || true; }

agents_list(){
  if ! _agents_configured; then
    printf '  %sno agents configured%s\n' "$DIM" "$N"
    printf '  %sadd one from the Agents menu in the Workframe wizard%s\n' "$DIM" "$N"
    return 0
  fi
  banner "agents"
  local a
  for a in $VALID_AGENTS; do
    printf '  %s%s%s\n' "$GRN" "$a" "$N"
  done
}

agents_add(){
  local name="${1:-}"
  [ -n "$name" ] || die "usage: workframe agents add <name>"
  name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
  _agent_name_ok "$name" || die "invalid agent name '$name' (use [a-z0-9._-]+)"
  _is_agent "$name" && { ok "already configured: $name"; return 0; }
  VALID_AGENTS=$(printf '%s %s' "$VALID_AGENTS" "$name" | tr -s ' ')
  VALID_AGENTS=${VALID_AGENTS# }
  _save_user_config
  ok "added agent ${GRN}$name${N}"
}

agents_remove(){
  local name=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f)
        die "unknown flag: $1 — archive that agent's worktrees first, then: workframe agents remove <name>"
        ;;
      -*)
        die "unknown flag: $1 (usage: workframe agents remove <name>)"
        ;;
      *)
        [ -z "$name" ] || die "usage: workframe agents remove <name>"
        name=$1
        shift
        ;;
    esac
  done
  [ -n "$name" ] || die "usage: workframe agents remove <name>"
  name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
  _is_agent "$name" || die "agent not configured: $name"
  local rows hit=0 ag
  rows=$(_list_agent_worktrees)
  while IFS=$'\t' read -r ag _; do
    [ "$ag" = "$name" ] && { hit=1; break; }
  done <<< "$rows"
  if [ "$hit" = 1 ]; then
    die "agent '$name' still has active worktrees — archive them first"
  fi
  local a next=""
  for a in $VALID_AGENTS; do
    [ "$a" = "$name" ] && continue
    next=$(printf '%s %s' "$next" "$a")
  done
  VALID_AGENTS=$(printf '%s' "$next" | tr -s ' ')
  VALID_AGENTS=${VALID_AGENTS# }
  _save_user_config
  ok "removed agent ${GRN}$name${N}"
}

# Resolve agent for `workframe new`: --agent / WORKFRAME_AGENT, else TTY picker, else usage error.
# Never falls back to a silent default.
_resolve_agent(){
  local agent="${1:-}"
  if [ -n "$agent" ]; then
    _is_agent "$agent" || die "unknown agent '$agent' — configure with: workframe agents add $agent"
    printf '%s' "$agent"
    return 0
  fi
  if [ -n "${WORKFRAME_AGENT:-}" ]; then
    _is_agent "$WORKFRAME_AGENT" || die "unknown agent '$WORKFRAME_AGENT' — configure with: workframe agents add $WORKFRAME_AGENT"
    printf '%s' "$WORKFRAME_AGENT"
    return 0
  fi
  if ! _agents_configured; then
    die "no agents configured — add one from the Agents menu in the Workframe wizard"
  fi
  if _interactive; then
    _agents_array
    local sel
    sel=$(_choose "which agent?" "${AGENTS_ARR[@]}") || return 1
    [ -n "$sel" ] || return 1
    printf '%s' "$sel"
    return 0
  fi
  die "usage: workframe new <repo> <feature> --agent <name>  (agents: $VALID_AGENTS)"
}

# Open path in a real IDE window. cursor/code get -n (new window); never --chat.
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
