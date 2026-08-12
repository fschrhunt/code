#!/usr/bin/env bats
# The public CLI exposes the small human workflow only.

load helper

setup() { _use_test_root; }

@test "setup creates the collection and remembers a custom root" {
  local root="$BATS_TEST_TMPDIR/custom workspaces"
  unset WORKSPACES_ROOT

  run "$WORKSPACES" setup --root "$root"

  [ "$status" -eq 0 ]
  root=$(cd -P "$root" && pwd)
  [ "$output" = "$root" ]
  [ -f "$root/README.md" ]
  [ "$(cat "$XDG_CONFIG_HOME/workspaces/root")" = "$root" ]
  [ ! -e "$root/repos" ]
  [ ! -e "$root/system" ]
}

@test "setup never replaces an existing README" {
  printf 'mine\n' > "$WORKSPACES_ROOT/README.md"

  run "$WORKSPACES" setup

  [ "$status" -eq 0 ]
  [ "$(cat "$WORKSPACES_ROOT/README.md")" = mine ]
}

@test "clone creates a normal checkout directly below the root" {
  local source="$BATS_TEST_TMPDIR/source"
  git init -q "$source"
  git -C "$source" config user.email t@example.com
  git -C "$source" config user.name tester
  git -C "$source" checkout -q -b main
  printf '# source\n' > "$source/README.md"
  git -C "$source" add README.md
  git -C "$source" commit -qm init

  run bash -c "'$WORKSPACES' clone '$source' 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = "$WORKSPACES_ROOT/source" ]
  [ -d "$WORKSPACES_ROOT/source/.git" ]
  [ "$(git -C "$WORKSPACES_ROOT/source" branch --show-current)" = main ]
}

@test "list shows normal repositories and task checkouts" {
  _seed_repo demo
  "$WORKSPACES" new demo docs >/dev/null

  run "$WORKSPACES" list

  [ "$status" -eq 0 ]
  [[ "$output" == *'Repositories'* ]]
  [[ "$output" == *"demo  main"* ]]
  [[ "$output" == *'Task worktrees'* ]]
  [[ "$output" == *'demo/docs'* ]]
}

@test "root prints the selected collection" {
  run "$WORKSPACES" root
  [ "$status" -eq 0 ]
  [ "$output" = "$WORKSPACES_ROOT" ]
}

@test "legacy lifecycle and automation commands are absent" {
  local command
  for command in archive restore migrate sync run path current worktrees repos update; do
    run "$WORKSPACES" "$command"
    [ "$status" -ne 0 ]
  done
}
