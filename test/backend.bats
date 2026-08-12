#!/usr/bin/env bats
# Nested worktree lifecycle and destructive-action safety.

load helper

setup() {
  _use_test_root
  _seed_repo demo
}

@test "new creates a task checkout under worktrees" {
  run "$WORKSPACES" new demo fix-login
  [ "$status" -eq 0 ]
  [ "$output" = "$WORKSPACES_ROOT/worktrees/demo/fix-login" ]
  [ -e "$output/.git" ]
  [ "$(git -C "$output" branch --show-current)" = fix-login ]
  local git_dir
  git_dir=$(git -C "$output" rev-parse --absolute-git-dir)
  [ -f "$git_dir/workspaces-managed" ]
}

@test "new chooses distinct path-safe world capitals when task is omitted" {
  local first second name

  first=$("$WORKSPACES" new demo)
  name=${first##*/}
  [[ "$name" =~ ^[a-z]+(-[a-z]+)*$ ]]
  [ "$(git -C "$first" branch --show-current)" = "$name" ]

  second=$("$WORKSPACES" new demo)
  [ "$second" != "$first" ]
  name=${second##*/}
  [[ "$name" =~ ^[a-z]+(-[a-z]+)*$ ]]
  [ "$(git -C "$second" branch --show-current)" = "$name" ]
}

@test "new branches from the repository checkout's current HEAD" {
  printf 'local\n' >> "$WORKSPACES_ROOT/repos/demo/README.md"
  git -C "$WORKSPACES_ROOT/repos/demo" add README.md
  git -C "$WORKSPACES_ROOT/repos/demo" commit -qm local

  run "$WORKSPACES" new demo current-head
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git -C "$WORKSPACES_ROOT/repos/demo" rev-parse HEAD)" ]
}

@test "new reattaches an existing inactive branch" {
  git -C "$WORKSPACES_ROOT/repos/demo" branch paused

  run "$WORKSPACES" new demo paused

  [ "$status" -eq 0 ]
  [ "$output" = "$WORKSPACES_ROOT/worktrees/demo/paused" ]
  [ "$(git -C "$output" branch --show-current)" = paused ]
}

@test "parallel tasks have independent working files" {
  local first second
  first=$("$WORKSPACES" new demo first)
  second=$("$WORKSPACES" new demo second)
  printf 'first\n' > "$first/task.txt"
  printf 'second\n' > "$second/task.txt"

  [ "$(cat "$first/task.txt")" = first ]
  [ "$(cat "$second/task.txt")" = second ]
  [ ! -e "$WORKSPACES_ROOT/repos/demo/task.txt" ]
}

@test "new disambiguates an occupied task name" {
  mkdir -p "$WORKSPACES_ROOT/worktrees/demo/collision"

  run "$WORKSPACES" new demo collision

  [ "$status" -eq 0 ]
  [ "$output" = "$WORKSPACES_ROOT/worktrees/demo/collision-2" ]
  [ -e "$output/.git" ]
}

@test "ownership survives branch and Git worktree renames" {
  local original moved
  original=$("$WORKSPACES" new demo initial)
  moved="$WORKSPACES_ROOT/worktrees/demo/better-name"
  git -C "$original" branch -m better-branch
  git -C "$WORKSPACES_ROOT/repos/demo" worktree move "$original" "$moved"

  run "$WORKSPACES" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo/better-branch"* ]]
  [[ "$output" == *"$moved"* ]]

  run "$WORKSPACES" remove demo/better-branch
  [ "$status" -eq 0 ]
  [ ! -e "$moved" ]
  git -C "$WORKSPACES_ROOT/repos/demo" show-ref --verify --quiet refs/heads/better-branch
}

@test "new refuses a marked branch moved outside its repository worktree folder" {
  local original outside
  original=$("$WORKSPACES" new demo moved)
  outside="$BATS_TEST_TMPDIR/outside"
  git -C "$WORKSPACES_ROOT/repos/demo" worktree move "$original" "$outside"

  run "$WORKSPACES" new demo moved

  [ "$status" -ne 0 ]
  [[ "$output" == *'outside worktrees/demo'* ]]
  [ -e "$outside/.git" ]
}

@test "unmarked worktrees are ignored and cannot be removed" {
  local foreign="$WORKSPACES_ROOT/worktrees/demo/manual"
  mkdir -p "$(dirname "$foreign")"
  git -C "$WORKSPACES_ROOT/repos/demo" worktree add -q -b manual "$foreign" HEAD

  run "$WORKSPACES" list
  [ "$status" -eq 0 ]
  [[ "$output" != *"demo/manual"* ]]

  run "$WORKSPACES" remove "$foreign"
  [ "$status" -ne 0 ]
  [ -e "$foreign/.git" ]
}

@test "remove refuses dirty work unless force is explicit" {
  local path
  path=$("$WORKSPACES" new demo dirty)
  printf 'change\n' > "$path/change.txt"

  run "$WORKSPACES" remove demo/dirty
  [ "$status" -eq 3 ]
  [ -e "$path/.git" ]

  run "$WORKSPACES" remove demo/dirty --force
  [ "$status" -eq 0 ]
  [ ! -e "$path" ]
  git -C "$WORKSPACES_ROOT/repos/demo" show-ref --verify --quiet refs/heads/dirty
}

@test "new rejects path-like task names" {
  local bad
  for bad in 'feature/auth' '../escape' 'two words' '-flag'; do
    run "$WORKSPACES" new demo "$bad"
    [ "$status" -ne 0 ]
  done
}
