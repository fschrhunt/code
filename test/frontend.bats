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
  grep -q '<root>/' "$root/README.md"
  ! grep -q '~/workspaces/' "$root/README.md"
  [ -d "$root/repos" ]
  [ -d "$root/worktrees" ]
  [ "$(cat "$XDG_CONFIG_HOME/workspaces/root")" = "$root" ]
  [ ! -e "$root/system" ]
}

@test "setup never replaces an existing README" {
  printf 'mine\n' > "$WORKSPACES_ROOT/README.md"

  run "$WORKSPACES" setup

  [ "$status" -eq 0 ]
  [ "$(cat "$WORKSPACES_ROOT/README.md")" = mine ]
}

@test "setup refreshes an unedited generated pre-4.0 README" {
  cp "$BATS_TEST_DIRNAME/../lib/README.pre-4.0.md" "$WORKSPACES_ROOT/README.md"

  run "$WORKSPACES" setup

  [ "$status" -eq 0 ]
  grep -q '<!-- workspaces-generated-readme -->' "$WORKSPACES_ROOT/README.md"
  grep -q 'repos/' "$WORKSPACES_ROOT/README.md"
}

@test "setup preserves edits to a generated README" {
  cp "$BATS_TEST_DIRNAME/../lib/README.md" "$WORKSPACES_ROOT/README.md"
  printf '\nMy local notes.\n' >> "$WORKSPACES_ROOT/README.md"

  run "$WORKSPACES" setup

  [ "$status" -eq 0 ]
  grep -q 'My local notes.' "$WORKSPACES_ROOT/README.md"
}

@test "setup moves legacy repositories and repairs active dirty tasks" {
  local task git_dir
  _seed_repo demo
  task=$("$WORKSPACES" new demo repair-me)
  printf 'base change\n' > "$WORKSPACES_ROOT/repos/demo/base.txt"
  printf 'task change\n' > "$task/task.txt"
  _make_legacy_repo demo "$task"

  run "$WORKSPACES" setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"moved: $WORKSPACES_ROOT/demo -> $WORKSPACES_ROOT/repos/demo (repaired 1 worktree(s))"* ]]
  [ ! -e "$WORKSPACES_ROOT/demo" ]
  [ -d "$WORKSPACES_ROOT/repos/demo/.git" ]
  [ "$(cat "$WORKSPACES_ROOT/repos/demo/base.txt")" = 'base change' ]
  [ "$(cat "$task/task.txt")" = 'task change' ]
  [ "$(git -C "$task" branch --show-current)" = repair-me ]
  git_dir=$(git -C "$task" rev-parse --absolute-git-dir)
  [ -f "$git_dir/workspaces-managed" ]

  run "$WORKSPACES" remove demo/repair-me
  [ "$status" -eq 3 ]
  [ -e "$task/.git" ]
}

@test "setup preflights every destination before changing repositories or README" {
  _seed_repo first
  _seed_repo second
  _make_legacy_repo first
  _make_legacy_repo second
  cp "$BATS_TEST_DIRNAME/../lib/README.pre-4.0.md" "$WORKSPACES_ROOT/README.md"
  cp "$WORKSPACES_ROOT/README.md" "$BATS_TEST_TMPDIR/README.before"
  mkdir "$WORKSPACES_ROOT/repos/second"
  printf 'keep\n' > "$WORKSPACES_ROOT/repos/second/marker"

  run "$WORKSPACES" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'destination already exists'* ]]
  [ -d "$WORKSPACES_ROOT/first/.git" ]
  [ -d "$WORKSPACES_ROOT/second/.git" ]
  [ "$(cat "$WORKSPACES_ROOT/repos/second/marker")" = keep ]
  cmp -s "$BATS_TEST_TMPDIR/README.before" "$WORKSPACES_ROOT/README.md"
}

@test "setup rolls every repository back when worktree repair fails" {
  local first_task second_task mockbin="$BATS_TEST_TMPDIR/mockbin" real_git
  real_git=$(command -v git)
  _seed_repo first
  first_task=$("$WORKSPACES" new first task-one)
  _make_legacy_repo first "$first_task"
  _seed_repo second
  second_task=$("$WORKSPACES" new second task-two)
  _make_legacy_repo second "$second_task"
  mkdir -p "$mockbin"
  cat > "$mockbin/git" <<'EOF'
#!/bin/sh
if [ "$1" = -C ] && [ "$3" = worktree ] && [ "$4" = repair ]; then
  case "$2" in */repos/second) exit 1;; esac
fi
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$mockbin/git"

  run env PATH="$mockbin:$PATH" REAL_GIT="$real_git" "$WORKSPACES" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'all moves were rolled back'* ]]
  [ -d "$WORKSPACES_ROOT/first/.git" ]
  [ -d "$WORKSPACES_ROOT/second/.git" ]
  [ ! -e "$WORKSPACES_ROOT/repos/first" ]
  [ ! -e "$WORKSPACES_ROOT/repos/second" ]
  git -C "$first_task" status --porcelain >/dev/null
  git -C "$second_task" status --porcelain >/dev/null
}

@test "setup refuses a symlinked collection root" {
  local target="$BATS_TEST_TMPDIR/root-target" link="$BATS_TEST_TMPDIR/root-link"
  mkdir "$target"
  ln -s "$target" "$link"

  run env WORKSPACES_ROOT="$link" "$WORKSPACES" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing symlinked collection root'* ]]
  [ -L "$link" ]
}

@test "setup --root refuses a symlinked collection root" {
  local target="$BATS_TEST_TMPDIR/root-target" link="$BATS_TEST_TMPDIR/root-link"
  mkdir "$target"
  ln -s "$target" "$link"
  unset WORKSPACES_ROOT

  run "$WORKSPACES" setup --root "$link"

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing symlinked collection root'* ]]
  [ -L "$link" ]
}

@test "setup symlinked collection directories" {
  local target="$BATS_TEST_TMPDIR/repos-target"
  mkdir "$target"
  ln -s "$target" "$WORKSPACES_ROOT/repos"

  run "$WORKSPACES" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing symlinked collection directory'* ]]
  [ -L "$WORKSPACES_ROOT/repos" ]
}

@test "setup refuses legacy repositories with reserved layout names" {
  git init -q "$WORKSPACES_ROOT/repos"

  run "$WORKSPACES" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"root-level repository named 'repos'"* ]]
  [ -d "$WORKSPACES_ROOT/repos/.git" ]
}

@test "setup refuses a collection README symlink" {
  local target="$BATS_TEST_TMPDIR/readme-target"
  printf 'keep\n' > "$target"
  ln -s "$target" "$WORKSPACES_ROOT/README.md"

  run "$WORKSPACES" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing to replace symlink'* ]]
  [ "$(cat "$target")" = keep ]
}

@test "list and doctor point legacy collections to setup without changing them" {
  _seed_repo demo
  _make_legacy_repo demo

  run "$WORKSPACES" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"run 'ws setup' to move them into repos/"* ]]

  run "$WORKSPACES" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"run 'ws setup' to move them into repos/"* ]]
  [ -d "$WORKSPACES_ROOT/demo/.git" ]
  [ ! -e "$WORKSPACES_ROOT/repos/demo" ]
}

@test "clone creates a normal checkout inside repos" {
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
  [ "$output" = "$WORKSPACES_ROOT/repos/source" ]
  [ -d "$WORKSPACES_ROOT/repos/source/.git" ]
  [ "$(git -C "$WORKSPACES_ROOT/repos/source" branch --show-current)" = main ]
}

@test "repository names cannot collide with collection directories" {
  local source="$BATS_TEST_TMPDIR/worktrees"
  git init -q "$source"

  run bash -c "'$WORKSPACES' clone '$source' 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = "$WORKSPACES_ROOT/repos/worktrees" ]
  [ -d "$WORKSPACES_ROOT/repos/worktrees/.git" ]
  [ -d "$WORKSPACES_ROOT/worktrees" ]
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
