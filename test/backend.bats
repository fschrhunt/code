#!/usr/bin/env bats
# Backend worktree lifecycle + destructive-action safety, exercised in-process
# (WORKFRAME_BACKEND=1) against a hermetic local store. This is the code path that the
# 2026-07-13 incident touched, so it gets the most coverage.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
}

@test "new creates a worktree on an agent branch" {
  run "$WORKFRAME" new codex demo fix-login
  [ "$status" -eq 0 ]
  local ws; ws=$(printf '%s\n' "$output" | _workspace_path)
  [ -n "$ws" ]
  [ -e "$ws/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/fix-login
  [ -n "$output" ]
}

@test "new without args is a usage error" {
  run "$WORKFRAME" new
  [ "$status" -ne 0 ]
  [[ "$output" == *usage* ]]
}

@test "list shows an active worktree" {
  "$WORKFRAME" new codex demo fix-login
  run "$WORKFRAME" list
  [ "$status" -eq 0 ]
  [[ "$output" == *demo* ]]
  [[ "$output" == *fix-login* ]]
}

@test "a store root with spaces keeps worktrees visible and deletion-safe" {
  local old_root=$WORKFRAME_HOME
  WORKFRAME_HOME="$BATS_TEST_TMPDIR/store with spaces"
  mv "$old_root" "$WORKFRAME_HOME"
  local ws; ws=$("$WORKFRAME" new codex demo spaced-root 2>/dev/null | _workspace_path)
  [ -e "$ws/.git" ]

  run "$WORKFRAME" worktrees
  [ "$status" -eq 0 ]
  [[ "$output" == *$'codex\tdemo\t'* ]]
  [[ "$output" == *"$ws"* ]]

  printf 'uncommitted\n' > "$ws/keep-me.txt"
  run "$WORKFRAME" remove repo demo
  [ "$status" -eq 3 ]
  [[ "$output" == *REFUSED* ]]
  [ -d "$WORKFRAME_HOME/repos/demo" ]
  [ -e "$ws/.git" ]

  run "$WORKFRAME" remove repo demo --force
  [ "$status" -eq 0 ]
  [ ! -d "$WORKFRAME_HOME/repos/demo" ]
  [ ! -e "$ws" ]
}

@test "archive removes the folder but keeps the branch; archived lists it" {
  local ws; ws=$("$WORKFRAME" new codex demo feat-x 2>/dev/null | _workspace_path)
  run "$WORKFRAME" archive "$ws"
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived: codex/feat-x"* ]]
  [ ! -e "$ws/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/feat-x
  [ -n "$output" ]
  run "$WORKFRAME" archived
  [[ "$output" == *feat-x* ]]
}

@test "archive refuses a dirty worktree without --force (exit 3)" {
  local ws; ws=$("$WORKFRAME" new codex demo dirty 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WORKFRAME" archive "$ws"
  [ "$status" -eq 3 ]
  [[ "$output" == *DIRTY* ]]
  [[ "$output" == *--force* ]]
}

@test "archive --yes does not discard dirty work" {
  local ws; ws=$("$WORKFRAME" new codex demo dirty-yes 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WORKFRAME" archive "$ws" --yes
  [ "$status" -eq 3 ]
  [[ "$output" == *DIRTY* ]]
  [ -e "$ws/.git" ]
}

@test "archive --force discards dirty work" {
  local ws; ws=$("$WORKFRAME" new codex demo dirty-force 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WORKFRAME" archive "$ws" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived: codex/dirty-force"* ]]
  [ ! -e "$ws/.git" ]
}

@test "archive refuses a path outside the workspace root" {
  run "$WORKFRAME" archive "$WORKFRAME_HOME/repos/demo"
  [ "$status" -ne 0 ]
  [[ "$output" == *refusing* ]]
}

@test "restore recreates a worktree from an archived branch" {
  local ws; ws=$("$WORKFRAME" new codex demo comeback 2>/dev/null | _workspace_path)
  "$WORKFRAME" archive "$ws" >/dev/null
  run "$WORKFRAME" restore demo codex/comeback
  [ "$status" -eq 0 ]
  local ws2; ws2=$(printf '%s\n' "$output" | _workspace_path)
  [ -e "$ws2/.git" ]
}

@test "rmbranch refuses while the branch is active" {
  "$WORKFRAME" new codex demo active >/dev/null 2>&1
  run "$WORKFRAME" rmbranch demo codex/active
  [ "$status" -ne 0 ]
  [[ "$output" == *active* ]]
}

@test "rmbranch deletes an archived branch permanently" {
  local ws; ws=$("$WORKFRAME" new codex demo gone 2>/dev/null | _workspace_path)
  "$WORKFRAME" archive "$ws" >/dev/null
  run "$WORKFRAME" rmbranch demo codex/gone
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed branch: codex/gone"* ]]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list codex/gone
  [ -z "$output" ]
}

@test "remove branch is a CLI alias for rmbranch" {
  local ws; ws=$("$WORKFRAME" new codex demo alias-rm 2>/dev/null | _workspace_path)
  "$WORKFRAME" archive "$ws" >/dev/null
  run "$WORKFRAME" remove branch demo codex/alias-rm
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed branch: codex/alias-rm"* ]]
}

@test "remove without subcommand is a usage error" {
  run "$WORKFRAME" remove
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: workframe remove branch"* ]]
}

@test "remove repo deletes a canonical clone" {
  "$WORKFRAME" new codex demo doomed >/dev/null 2>&1
  run "$WORKFRAME" remove repo demo --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted repo: demo"* ]]
  [ ! -d "$WORKFRAME_HOME/repos/demo" ]
}

@test "remove repo accepts --yes before --force" {
  "$WORKFRAME" new codex demo flag-order >/dev/null 2>&1
  # --yes before --force must still discard dirty (flag-order regression).
  run "$WORKFRAME" remove repo demo --yes --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted repo: demo"* ]]
  [ ! -d "$WORKFRAME_HOME/repos/demo" ]
}

@test "clean is a dry run by default" {
  "$WORKFRAME" new codex demo keep >/dev/null 2>&1
  run "$WORKFRAME" clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run"* ]]
}

@test "clean prunes metadata for an orphaned worktree" {
  local ws; ws=$("$WORKFRAME" new codex demo orphaned 2>/dev/null | _workspace_path)
  rm "$ws/.git"

  run "$WORKFRAME" clean --yes
  [ "$status" -eq 0 ]
  [ ! -e "$ws" ]

  run git -C "$WORKFRAME_HOME/repos/demo" worktree list --porcelain
  [[ "$output" != *"$ws"* ]]
  run "$WORKFRAME" archived
  [ "$status" -eq 0 ]
  [[ "$output" == *$'codex\tdemo\tcodex/orphaned'* ]]
}

@test "remove repo refuses path-traversal names" {
  run "$WORKFRAME" remove repo '../escape' --force --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid repo name"* ]]
}

@test "remove repo REFUSED when worktree is dirty without --force" {
  local ws; ws=$("$WORKFRAME" new codex demo at-risk 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WORKFRAME" remove repo demo
  [ "$status" -eq 3 ]
  [[ "$output" == *REFUSED* ]]
  [ -d "$WORKFRAME_HOME/repos/demo" ]
}

@test "clone_repo_name parses https and git@ specs" {
  run bash -c '
    export WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="'"$WORKFRAME_HOME"'"
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
  mkdir -p "$WORKFRAME_HOME/system/config"
  printf 'type = local\neditor = cursor\nagents = codex\n' > "$WORKFRAME_HOME/system/config/workframe.conf"
  run env WORKFRAME_HOME="$WORKFRAME_HOME" WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 "$WORKFRAME" clone lonely
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

  run env WORKFRAME_HOME="$WORKFRAME_HOME" WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 "$WORKFRAME" clone "$origin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cloned: origin-demo"* ]]
  [ -d "$WORKFRAME_HOME/repos/origin-demo/.git" ]

  rm -rf "$WORKFRAME_HOME/repos/origin-demo"
  run env WORKFRAME_HOME="$WORKFRAME_HOME" WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 "$WORKFRAME" clone "file://$origin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cloned: origin-demo"* ]]
  [ -d "$WORKFRAME_HOME/repos/origin-demo/.git" ]
}

@test "new after archive points at restore" {
  local ws; ws=$("$WORKFRAME" new codex demo comeback-new 2>/dev/null | _workspace_path)
  "$WORKFRAME" archive "$ws" >/dev/null
  run "$WORKFRAME" new codex demo comeback-new
  [ "$status" -ne 0 ]
  [[ "$output" == *"archived"* ]]
  [[ "$output" == *"workframe restore demo codex/comeback-new"* ]]
}

@test "new when branch is active says so" {
  "$WORKFRAME" new codex demo live-dup >/dev/null 2>&1
  run "$WORKFRAME" new codex demo live-dup
  [ "$status" -ne 0 ]
  [[ "$output" == *"already active"* ]]
}

@test "new without a cloned repo points at clone" {
  run "$WORKFRAME" new codex missing feat
  [ "$status" -ne 0 ]
  [[ "$output" == *"clone first"* ]]
}

@test "pick_city samples unique folder labels" {
  run bash -c '
    export WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="'"$WORKFRAME_HOME"'"
    WORKFRAME_PREFIX="'"$BATS_TEST_DIRNAME/.."'"
    WORKFRAME_LIB="$WORKFRAME_PREFIX/lib"
    . "$WORKFRAME_LIB/config.sh"
    . "$WORKFRAME_LIB/palette.sh"
    . "$WORKFRAME_LIB/ui.sh"
    . "$WORKFRAME_LIB/agents.sh"
    . "$WORKFRAME_LIB/backend.sh"
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
  run "$WORKFRAME" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktrees:"* ]]
  [[ "$output" == *"canonicals:"* ]]
}

@test "unknown backend command errors" {
  run "$WORKFRAME" frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
}

# Land a new commit on the seeded origin so the canonical falls behind.
_advance_origin() {
  local seed="$BATS_TEST_TMPDIR/demo-seed"
  echo upstream > "$seed/upstream.txt"
  git -C "$seed" add -A
  git -C "$seed" commit -qm "upstream change"
  git -C "$seed" push -q origin main
}

@test "sync fast-forwards a clean canonical that is behind" {
  _advance_origin
  run "$WORKFRAME" sync demo
  [ "$status" -eq 0 ]
  # The checkout moved, not just the refs.
  [ -f "$WORKFRAME_HOME/repos/demo/upstream.txt" ]
  run git -C "$WORKFRAME_HOME/repos/demo" rev-list --count HEAD..origin/main
  [ "$output" = "0" ]
}

@test "sync leaves a dirty canonical alone" {
  _advance_origin
  echo local-edit >> "$WORKFRAME_HOME/repos/demo/README.md"
  run "$WORKFRAME" sync demo
  [ "$status" -eq 0 ]
  [[ "$output" == *dirty* ]]
  # Refs fetched, but the working tree was left untouched.
  [ ! -f "$WORKFRAME_HOME/repos/demo/upstream.txt" ]
  run git -C "$WORKFRAME_HOME/repos/demo" rev-list --count HEAD..origin/main
  [ "$output" = "1" ]
}

@test "sync leaves a diverged canonical alone" {
  _advance_origin
  git -C "$WORKFRAME_HOME/repos/demo" config user.email t@example.com
  git -C "$WORKFRAME_HOME/repos/demo" config user.name tester
  echo local > "$WORKFRAME_HOME/repos/demo/local.txt"
  git -C "$WORKFRAME_HOME/repos/demo" add -A
  git -C "$WORKFRAME_HOME/repos/demo" commit -qm "local commit"
  run "$WORKFRAME" sync demo
  [ "$status" -eq 0 ]
  [[ "$output" == *diverged* ]]
  [ ! -f "$WORKFRAME_HOME/repos/demo/upstream.txt" ]
}

@test "archive accepts a worktree path reached through a symlinked store root" {
  # A store on an attached volume (or /tmp on macOS) is reached through a
  # symlink, while $WORK is physical — the containment check must still match.
  local ws; ws=$("$WORKFRAME" new codex demo linkpath | _workspace_path)
  local link="$BATS_TEST_TMPDIR/link"
  ln -s "$WORKFRAME_HOME" "$link"
  # $ws is physical; take the agent/repo/city tail rather than assuming a prefix.
  local via_link="$link/workspaces/${ws#*/workspaces/}"
  [ -e "$via_link/.git" ]
  run "$WORKFRAME" archive "$via_link"
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived: codex/linkpath"* ]]
  [ ! -d "$ws" ]
}

@test "archive still refuses a path outside the store" {
  run "$WORKFRAME" archive "$BATS_TEST_TMPDIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not under workspaces/"* ]]
}
