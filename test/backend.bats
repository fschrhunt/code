#!/usr/bin/env bats
# Backend worktree lifecycle + destructive-action safety, exercised in-process
# (WT_BACKEND=1) against a hermetic local store. This is the code path that the
# 2026-07-13 incident touched, so it gets the most coverage.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
}

@test "new creates a worktree on an agent branch" {
  run "$WT" new codex demo fix-login
  [ "$status" -eq 0 ]
  local ws; ws=$(printf '%s\n' "$output" | _workspace_path)
  [ -n "$ws" ]
  [ -e "$ws/.git" ]
  run git -C "$WT_HOME/repos/demo" branch --list codex/fix-login
  [ -n "$output" ]
}

@test "new without args is a usage error" {
  run "$WT" new
  [ "$status" -ne 0 ]
  [[ "$output" == *usage* ]]
}

@test "list shows an active worktree" {
  "$WT" new codex demo fix-login
  run "$WT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *demo* ]]
  [[ "$output" == *fix-login* ]]
}

@test "archive removes the folder but keeps the branch; archived lists it" {
  local ws; ws=$("$WT" new codex demo feat-x 2>/dev/null | _workspace_path)
  run "$WT" archive "$ws"
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived: codex/feat-x"* ]]
  [ ! -e "$ws/.git" ]
  run git -C "$WT_HOME/repos/demo" branch --list codex/feat-x
  [ -n "$output" ]
  run "$WT" archived
  [[ "$output" == *feat-x* ]]
}

@test "archive refuses a dirty worktree without --force (exit 3)" {
  local ws; ws=$("$WT" new codex demo dirty 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WT" archive "$ws"
  [ "$status" -eq 3 ]
  [[ "$output" == *DIRTY* ]]
  [[ "$output" == *--force* ]]
}

@test "archive --yes does not discard dirty work" {
  local ws; ws=$("$WT" new codex demo dirty-yes 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WT" archive "$ws" --yes
  [ "$status" -eq 3 ]
  [[ "$output" == *DIRTY* ]]
  [ -e "$ws/.git" ]
}

@test "archive --force discards dirty work" {
  local ws; ws=$("$WT" new codex demo dirty-force 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WT" archive "$ws" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived: codex/dirty-force"* ]]
  [ ! -e "$ws/.git" ]
}

@test "archive refuses a path outside the workspace root" {
  run "$WT" archive "$WT_HOME/repos/demo"
  [ "$status" -ne 0 ]
  [[ "$output" == *refusing* ]]
}

@test "restore recreates a worktree from an archived branch" {
  local ws; ws=$("$WT" new codex demo comeback 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" restore demo codex/comeback
  [ "$status" -eq 0 ]
  local ws2; ws2=$(printf '%s\n' "$output" | _workspace_path)
  [ -e "$ws2/.git" ]
}

@test "rmbranch refuses while the branch is active" {
  "$WT" new codex demo active >/dev/null 2>&1
  run "$WT" rmbranch demo codex/active
  [ "$status" -ne 0 ]
  [[ "$output" == *active* ]]
}

@test "rmbranch deletes an archived branch permanently" {
  local ws; ws=$("$WT" new codex demo gone 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" rmbranch demo codex/gone
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed branch: codex/gone"* ]]
  run git -C "$WT_HOME/repos/demo" branch --list codex/gone
  [ -z "$output" ]
}

@test "remove branch is a CLI alias for rmbranch" {
  local ws; ws=$("$WT" new codex demo alias-rm 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" remove branch demo codex/alias-rm
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed branch: codex/alias-rm"* ]]
}

@test "remove without subcommand is a usage error" {
  run "$WT" remove
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: wt remove branch"* ]]
}

@test "remove repo deletes a canonical clone" {
  "$WT" new codex demo doomed >/dev/null 2>&1
  run "$WT" remove repo demo --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted repo: demo"* ]]
  [ ! -d "$WT_HOME/repos/demo" ]
}

@test "remove repo accepts --yes before --force" {
  "$WT" new codex demo flag-order >/dev/null 2>&1
  # --yes before --force must still discard dirty (flag-order regression).
  run "$WT" remove repo demo --yes --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted repo: demo"* ]]
  [ ! -d "$WT_HOME/repos/demo" ]
}

@test "clean is a dry run by default" {
  "$WT" new codex demo keep >/dev/null 2>&1
  run "$WT" clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run"* ]]
}

@test "remove repo refuses path-traversal names" {
  run "$WT" remove repo '../escape' --force --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid repo name"* ]]
}

@test "remove repo REFUSED when worktree is dirty without --force" {
  local ws; ws=$("$WT" new codex demo at-risk 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WT" remove repo demo
  [ "$status" -eq 3 ]
  [[ "$output" == *REFUSED* ]]
  [ -d "$WT_HOME/repos/demo" ]
}

@test "clone_repo_name parses https and git@ specs" {
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    printf "%s\n" "$(_clone_repo_name https://github.com/acme/widget.git)"
    printf "%s\n" "$(_clone_repo_name git@github.com:acme/widget.git)"
    printf "%s\n" "$(_clone_repo_name git@host:solo)"
    printf "%s\n" "$(_clone_repo_name acme/widget)"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'widget\nwidget\nsolo\nwidget' ]
}

@test "clone without default org refuses bare names" {
  printf 'type = local\neditor = cursor\nagents = codex\n' > "$WT_HOME/config"
  run env WT_HOME="$WT_HOME" WT_BACKEND=1 WT_COLOR=0 "$WT" clone lonely
  [ "$status" -ne 0 ]
  [[ "$output" == *"no default org"* ]]
}

@test "clone accepts local bare path and file:// URL" {
  local origin="$BATS_TEST_TMPDIR/origin-demo.git"
  local seed="$BATS_TEST_TMPDIR/seed-demo"
  git init -q --bare "$origin"
  git init -q "$seed"
  git -C "$seed" config user.email t@example.com
  git -C "$seed" config user.name tester
  git -C "$seed" checkout -q -b main
  printf 'ok\n' > "$seed/README.md"
  git -C "$seed" add -A
  git -C "$seed" commit -qm init
  git -C "$seed" remote add origin "$origin"
  git -C "$seed" push -q -u origin main
  git -C "$origin" symbolic-ref HEAD refs/heads/main

  run env WT_HOME="$WT_HOME" WT_BACKEND=1 WT_COLOR=0 "$WT" clone "$origin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cloned: origin-demo"* ]]
  [ -d "$WT_HOME/repos/origin-demo/.git" ]

  rm -rf "$WT_HOME/repos/origin-demo"
  run env WT_HOME="$WT_HOME" WT_BACKEND=1 WT_COLOR=0 "$WT" clone "file://$origin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cloned: origin-demo"* ]]
  [ -d "$WT_HOME/repos/origin-demo/.git" ]
}

@test "new after archive points at restore" {
  local ws; ws=$("$WT" new codex demo comeback-new 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" new codex demo comeback-new
  [ "$status" -ne 0 ]
  [[ "$output" == *"archived"* ]]
  [[ "$output" == *"wt restore demo codex/comeback-new"* ]]
}

@test "new when branch is active says so" {
  "$WT" new codex demo live-dup >/dev/null 2>&1
  run "$WT" new codex demo live-dup
  [ "$status" -ne 0 ]
  [[ "$output" == *"already active"* ]]
}

@test "new without a cloned repo points at clone" {
  run "$WT" new codex missing feat
  [ "$status" -ne 0 ]
  [[ "$output" == *"clone first"* ]]
}

@test "pick_city samples unique folder labels" {
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    WT_PREFIX="'"$BATS_TEST_DIRNAME/.."'"
    WT_LIB="$WT_PREFIX/lib"
    . "$WT_LIB/config.sh"
    . "$WT_LIB/palette.sh"
    . "$WT_LIB/ui.sh"
    . "$WT_LIB/agents.sh"
    . "$WT_LIB/backend.sh"
    dir="$WORK/codex/demo"
    mkdir -p "$dir"
    a=$(_pick_city codex demo)
    mkdir -p "$dir/$a"
    b=$(_pick_city codex demo)
    [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]
    printf "%s\n%s\n" "$a" "$b"
  '
  [ "$status" -eq 0 ]
  local a b
  a=$(printf '%s\n' "$output" | sed -n '1p')
  b=$(printf '%s\n' "$output" | sed -n '2p')
  [[ "$a" =~ ^[a-z][a-z0-9]+$ ]]
  [[ "$b" =~ ^[a-z][a-z0-9]+$ ]]
}

@test "status is a cheap glance" {
  run "$WT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktrees:"* ]]
  [[ "$output" == *"canonicals:"* ]]
}

@test "unknown backend command errors" {
  run "$WT" frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
}
