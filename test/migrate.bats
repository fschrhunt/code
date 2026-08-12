#!/usr/bin/env bats
# Legacy agent-layout migration is explicit, local-Git-only, and reversible.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
  printf 'type = local\neditor = cursor\ndefault_org = example\nagents = codex, claude\n' > "$WORKFRAME_HOME/system/config/workframe.conf"
}

_legacy_workspace() {
  local agent=${1:-codex} task=${2:-legacy} city=${3:-oldtown}
  local path="$WORKFRAME_HOME/workspaces/$agent/demo/$city"
  mkdir -p "$(dirname "$path")"
  git -C "$WORKFRAME_HOME/repos/demo" worktree add -q -b "$agent/$task" "$path" origin/main
  printf '%s' "$path"
}

@test "migrate defaults to a dry run" {
  local old; old=$(_legacy_workspace)
  run "$WORKFRAME" migrate
  [ "$status" -eq 0 ]
  [[ "$output" == *'dry run'* ]]
  [ -e "$old/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/legacy
  [ -n "$output" ]
}

@test "migrate moves active and archived legacy work without touching changes" {
  local old; old=$(_legacy_workspace codex live oldtown)
  printf 'uncommitted\n' > "$old/keep.txt"
  git -C "$WORKFRAME_HOME/repos/demo" branch claude/paused origin/main
  run "$WORKFRAME" migrate --yes
  [ "$status" -eq 0 ]
  local moved="$WORKFRAME_HOME/workspaces/demo/oldtown"
  [ -e "$moved/.git" ]
  [ "$(cat "$moved/keep.txt")" = uncommitted ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list live paused
  [[ "$output" == *live* ]]
  [[ "$output" == *paused* ]]
  git -C "$WORKFRAME_HOME/repos/demo" show-ref --verify --quiet refs/workframe/managed/live
  git -C "$WORKFRAME_HOME/repos/demo" show-ref --verify --quiet refs/workframe/managed/paused
  ! grep -q '^agents =' "$WORKFRAME_HOME/system/config/workframe.conf"
}

@test "migrate refuses path or branch collisions before changing anything" {
  local old; old=$(_legacy_workspace codex collide oldtown)
  mkdir -p "$WORKFRAME_HOME/workspaces/demo/oldtown"
  run "$WORKFRAME" migrate --yes
  [ "$status" -ne 0 ]
  [ -e "$old/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/collide
  [ -n "$output" ]
}

@test "migrate preflights collisions between two legacy agents" {
  local first second
  first=$(_legacy_workspace codex duplicate onecity)
  second=$(_legacy_workspace claude duplicate twocity)
  run "$WORKFRAME" migrate --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *'multiple legacy branches map to: demo/duplicate'* ]]
  [ -e "$first/.git" ]
  [ -e "$second/.git" ]
}

@test "migrate rolls completed operations back on failure" {
  local first second
  first=$(_legacy_workspace codex one firstcity)
  second=$(_legacy_workspace claude two secondcity)
  run env WORKFRAME_MIGRATE_FAIL_AFTER=1 "$WORKFRAME" migrate --yes
  [ "$status" -ne 0 ]
  [ -e "$first/.git" ]
  [ -e "$second/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/one claude/two
  [[ "$output" == *codex/one* ]]
  [[ "$output" == *claude/two* ]]
  grep -q '^agents = codex, claude$' "$WORKFRAME_HOME/system/config/workframe.conf"
}

@test "migrate rolls Git operations back when removing legacy config fails" {
  local old; old=$(_legacy_workspace codex config-failure oldtown)
  run env WORKFRAME_MIGRATE_FAIL_CONFIG_SAVE=1 "$WORKFRAME" migrate --yes
  [ "$status" -ne 0 ]
  [ -e "$old/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/config-failure
  [ -n "$output" ]
  ! git -C "$WORKFRAME_HOME/repos/demo" show-ref --verify --quiet refs/heads/config-failure
  grep -q '^agents = codex, claude$' "$WORKFRAME_HOME/system/config/workframe.conf"
}
