#!/usr/bin/env bats
# The public CLI exposes the small human workflow only.

load helper

setup() { _use_test_root; }

@test "setup --yes creates the default collection without prompting" {
  rm -rf "$CODE_ROOT"

  run bash -c "printf 'ignored input\\n' | '$CODE' setup --yes"

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT" ]
  [ -d "$CODE_ROOT/repos" ]
  [ -d "$CODE_ROOT/worktrees" ]
}

@test "setup accepts home shorthand through --root" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"
  unset CODE_ROOT

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" "$CODE" setup --root '~/Code' --yes

  [ "$status" -eq 0 ]
  home=$(cd -P "$home" && pwd)
  [ "$output" = "$home/Code" ]
  [ -d "$home/Code/repos" ]
  [ "$(cat "$XDG_CONFIG_HOME/code/root")" = "$home/Code" ]
}

@test "setup creates the collection and remembers a custom root" {
  local root="$BATS_TEST_TMPDIR/custom code"
  unset CODE_ROOT

  run "$CODE" setup --root "$root"

  [ "$status" -eq 0 ]
  root=$(cd -P "$root" && pwd)
  [ "$output" = "$root" ]
  [ -f "$root/README.md" ]
  grep -q '<root>/' "$root/README.md"
  ! grep -q '~/Code/' "$root/README.md"
  [ -d "$root/repos" ]
  [ -d "$root/worktrees" ]
  [ "$(cat "$XDG_CONFIG_HOME/code/root")" = "$root" ]
  [ ! -e "$root/system" ]
}

@test "setup never replaces an existing README" {
  printf 'mine\n' > "$CODE_ROOT/README.md"

  run "$CODE" setup

  [ "$status" -eq 0 ]
  [ "$(cat "$CODE_ROOT/README.md")" = mine ]
}

@test "setup refreshes an unedited generated pre-4.0 README" {
  cp "$BATS_TEST_DIRNAME/../lib/README.pre-4.0.md" "$CODE_ROOT/README.md"

  run "$CODE" setup

  [ "$status" -eq 0 ]
  grep -q '<!-- code-generated-readme -->' "$CODE_ROOT/README.md"
  grep -q 'repos/' "$CODE_ROOT/README.md"
}

@test "setup preserves edits to a generated README" {
  cp "$BATS_TEST_DIRNAME/../lib/README.md" "$CODE_ROOT/README.md"
  printf '\nMy local notes.\n' >> "$CODE_ROOT/README.md"

  run "$CODE" setup

  [ "$status" -eq 0 ]
  grep -q 'My local notes.' "$CODE_ROOT/README.md"
}

@test "setup moves legacy repositories and repairs active dirty tasks" {
  local task git_dir
  _seed_repo demo
  task=$("$CODE" new demo repair-me)
  printf 'base change\n' > "$CODE_ROOT/repos/demo/base.txt"
  printf 'task change\n' > "$task/task.txt"
  _make_legacy_repo demo "$task"

  run "$CODE" setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"moved: $CODE_ROOT/demo -> $CODE_ROOT/repos/demo (repaired 1 worktree(s))"* ]]
  [ ! -e "$CODE_ROOT/demo" ]
  [ -d "$CODE_ROOT/repos/demo/.git" ]
  [ "$(cat "$CODE_ROOT/repos/demo/base.txt")" = 'base change' ]
  [ "$(cat "$task/task.txt")" = 'task change' ]
  [ "$(git -C "$task" branch --show-current)" = repair-me ]
  git_dir=$(git -C "$task" rev-parse --absolute-git-dir)
  [ -f "$git_dir/code-managed" ]

  run "$CODE" remove demo/repair-me
  [ "$status" -eq 3 ]
  [ -e "$task/.git" ]
}

@test "setup preflights every destination before changing repositories or README" {
  _seed_repo first
  _seed_repo second
  _make_legacy_repo first
  _make_legacy_repo second
  cp "$BATS_TEST_DIRNAME/../lib/README.pre-4.0.md" "$CODE_ROOT/README.md"
  cp "$CODE_ROOT/README.md" "$BATS_TEST_TMPDIR/README.before"
  mkdir "$CODE_ROOT/repos/second"
  printf 'keep\n' > "$CODE_ROOT/repos/second/marker"

  run "$CODE" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'destination already exists'* ]]
  [ -d "$CODE_ROOT/first/.git" ]
  [ -d "$CODE_ROOT/second/.git" ]
  [ "$(cat "$CODE_ROOT/repos/second/marker")" = keep ]
  cmp -s "$BATS_TEST_TMPDIR/README.before" "$CODE_ROOT/README.md"
}

@test "setup rolls every repository back when worktree repair fails" {
  local first_task second_task mockbin="$BATS_TEST_TMPDIR/mockbin" real_git
  real_git=$(command -v git)
  _seed_repo first
  first_task=$("$CODE" new first task-one)
  _make_legacy_repo first "$first_task"
  _seed_repo second
  second_task=$("$CODE" new second task-two)
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

  run env PATH="$mockbin:$PATH" REAL_GIT="$real_git" "$CODE" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'all moves were rolled back'* ]]
  [ -d "$CODE_ROOT/first/.git" ]
  [ -d "$CODE_ROOT/second/.git" ]
  [ ! -e "$CODE_ROOT/repos/first" ]
  [ ! -e "$CODE_ROOT/repos/second" ]
  git -C "$first_task" status --porcelain >/dev/null
  git -C "$second_task" status --porcelain >/dev/null
}

@test "setup refuses a symlinked collection root" {
  local target="$BATS_TEST_TMPDIR/root-target" link="$BATS_TEST_TMPDIR/root-link"
  mkdir "$target"
  ln -s "$target" "$link"

  run env CODE_ROOT="$link" "$CODE" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing symlinked collection root'* ]]
  [ -L "$link" ]
}

@test "setup --root refuses a symlinked collection root" {
  local target="$BATS_TEST_TMPDIR/root-target" link="$BATS_TEST_TMPDIR/root-link"
  mkdir "$target"
  ln -s "$target" "$link"
  unset CODE_ROOT

  run "$CODE" setup --root "$link"

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing symlinked collection root'* ]]
  [ -L "$link" ]
}

@test "setup symlinked collection directories" {
  local target="$BATS_TEST_TMPDIR/repos-target"
  mkdir "$target"
  ln -s "$target" "$CODE_ROOT/repos"

  run "$CODE" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing symlinked collection directory'* ]]
  [ -L "$CODE_ROOT/repos" ]
}

@test "setup refuses legacy repositories with reserved layout names" {
  git init -q "$CODE_ROOT/repos"

  run "$CODE" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"root-level repository named 'repos'"* ]]
  [ -d "$CODE_ROOT/repos/.git" ]
}

@test "setup refuses a collection README symlink" {
  local target="$BATS_TEST_TMPDIR/readme-target"
  printf 'keep\n' > "$target"
  ln -s "$target" "$CODE_ROOT/README.md"

  run "$CODE" setup

  [ "$status" -ne 0 ]
  [[ "$output" == *'refusing to replace symlink'* ]]
  [ "$(cat "$target")" = keep ]
}

@test "list and doctor point legacy collections to setup without changing them" {
  _seed_repo demo
  _make_legacy_repo demo

  run "$CODE" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"run 'code setup' to move them into repos/"* ]]

  run "$CODE" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"run 'code setup' to move them into repos/"* ]]
  [ -d "$CODE_ROOT/demo/.git" ]
  [ ! -e "$CODE_ROOT/repos/demo" ]
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

  run bash -c "'$CODE' clone '$source' 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/repos/source" ]
  [ -d "$CODE_ROOT/repos/source/.git" ]
  [ "$(git -C "$CODE_ROOT/repos/source" branch --show-current)" = main ]
}

@test "an empty clone can create an unnamed task worktree" {
  local source="$BATS_TEST_TMPDIR/empty-source" path name git_dir
  git init -q "$source"
  "$CODE" clone "$source" >/dev/null 2>&1

  run "$CODE" new empty-source

  [ "$status" -eq 0 ]
  path=$output
  name=${path##*/}
  [ "$path" = "$CODE_ROOT/worktrees/empty-source/$name" ]
  [ "$(git -C "$path" branch --show-current)" = "$name" ]
  git_dir=$(git -C "$path" rev-parse --absolute-git-dir)
  [ -f "$git_dir/code-managed" ]
}

@test "repository names cannot collide with collection directories" {
  local source="$BATS_TEST_TMPDIR/worktrees"
  git init -q "$source"

  run bash -c "'$CODE' clone '$source' 2>/dev/null"

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/repos/worktrees" ]
  [ -d "$CODE_ROOT/repos/worktrees/.git" ]
  [ -d "$CODE_ROOT/worktrees" ]
}

@test "list shows normal repositories and task checkouts" {
  _seed_repo demo
  "$CODE" new demo docs >/dev/null

  run "$CODE" list

  [ "$status" -eq 0 ]
  [[ "$output" == *'Repositories'* ]]
  [[ "$output" == *"demo  main"* ]]
  [[ "$output" == *'Task worktrees'* ]]
  [[ "$output" == *'demo/docs'* ]]
}

@test "root prints the selected collection" {
  run "$CODE" root
  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT" ]
}

@test "legacy lifecycle and automation commands are absent" {
  local command
  for command in archive restore migrate sync run path current worktrees repos update; do
    run "$CODE" "$command"
    [ "$status" -ne 0 ]
  done
}
