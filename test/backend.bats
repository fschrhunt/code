#!/usr/bin/env bats
# Nested worktree lifecycle and destructive-action safety.

load helper

setup() {
  _use_test_root
  _seed_repo demo
}

@test "new creates a task checkout under worktrees" {
  run "$CODE" new demo fix-login
  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/demo/fix-login" ]
  [ -e "$output/.git" ]
  [ "$(git -C "$output" branch --show-current)" = fix-login ]
  local git_dir
  git_dir=$(git -C "$output" rev-parse --absolute-git-dir)
  [ -f "$git_dir/code-managed" ]
}

@test "new chooses distinct path-safe world capitals when task is omitted" {
  local first second name

  first=$("$CODE" new demo)
  name=${first##*/}
  [[ "$name" =~ ^[a-z]+(-[a-z]+)*$ ]]
  [ "$(git -C "$first" branch --show-current)" = "$name" ]

  second=$("$CODE" new demo)
  [ "$second" != "$first" ]
  name=${second##*/}
  [[ "$name" =~ ^[a-z]+(-[a-z]+)*$ ]]
  [ "$(git -C "$second" branch --show-current)" = "$name" ]
}

@test "new discovers a directly cloned repository from the current folder" {
  mkdir -p "$CODE_ROOT/repos/demo/nested"
  cd "$CODE_ROOT/repos/demo/nested"

  run "$CODE" new

  [ "$status" -eq 0 ]
  [[ "$output" == "$CODE_ROOT/worktrees/demo/"* ]]
  [ -e "$output/.git" ]
}

@test "new does not discover a clone outside repos" {
  local origin outside="$BATS_TEST_TMPDIR/outside"
  origin=$(git -C "$CODE_ROOT/repos/demo" remote get-url origin)
  git clone -q "$origin" "$outside"
  cd "$outside"

  run "$CODE" new

  [ "$status" -ne 0 ]
  [[ "$output" == *"run from $CODE_ROOT/repos/<repo> or pass <repo>"* ]]
  [ ! -e "$CODE_ROOT/worktrees/outside" ]
}

@test "new branches from the repository checkout's current HEAD" {
  printf 'local\n' >> "$CODE_ROOT/repos/demo/README.md"
  git -C "$CODE_ROOT/repos/demo" add README.md
  git -C "$CODE_ROOT/repos/demo" commit -qm local

  run "$CODE" new demo current-head
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git -C "$CODE_ROOT/repos/demo" rev-parse HEAD)" ]
}

@test "new reattaches an existing inactive branch" {
  git -C "$CODE_ROOT/repos/demo" branch paused

  run "$CODE" new demo paused

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/demo/paused" ]
  [ "$(git -C "$output" branch --show-current)" = paused ]
}

@test "parallel tasks have independent working files" {
  local first second
  first=$("$CODE" new demo first)
  second=$("$CODE" new demo second)
  printf 'first\n' > "$first/task.txt"
  printf 'second\n' > "$second/task.txt"

  [ "$(cat "$first/task.txt")" = first ]
  [ "$(cat "$second/task.txt")" = second ]
  [ ! -e "$CODE_ROOT/repos/demo/task.txt" ]
}

@test "new disambiguates an occupied task name" {
  mkdir -p "$CODE_ROOT/worktrees/demo/collision"

  run "$CODE" new demo collision

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/demo/collision-2" ]
  [ -e "$output/.git" ]
}

@test "ownership survives branch and Git worktree renames" {
  local original moved
  original=$("$CODE" new demo initial)
  moved="$CODE_ROOT/worktrees/demo/better-name"
  git -C "$original" branch -m better-branch
  git -C "$CODE_ROOT/repos/demo" worktree move "$original" "$moved"

  run "$CODE" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo/better-branch"* ]]
  [[ "$output" == *"$moved"* ]]

  run "$CODE" remove demo/better-branch
  [ "$status" -eq 0 ]
  [ ! -e "$moved" ]
  git -C "$CODE_ROOT/repos/demo" show-ref --verify --quiet refs/heads/better-branch
}

@test "new refuses a marked branch moved outside its repository worktree folder" {
  local original outside
  original=$("$CODE" new demo moved)
  outside="$BATS_TEST_TMPDIR/outside"
  git -C "$CODE_ROOT/repos/demo" worktree move "$original" "$outside"

  run "$CODE" new demo moved

  [ "$status" -ne 0 ]
  [[ "$output" == *'outside worktrees/demo'* ]]
  [ -e "$outside/.git" ]
}

@test "unmarked worktrees are ignored and cannot be removed" {
  local foreign="$CODE_ROOT/worktrees/demo/manual"
  mkdir -p "$(dirname "$foreign")"
  git -C "$CODE_ROOT/repos/demo" worktree add -q -b manual "$foreign" HEAD

  run "$CODE" list
  [ "$status" -eq 0 ]
  [[ "$output" != *"demo/manual"* ]]

  run "$CODE" remove "$foreign"
  [ "$status" -ne 0 ]
  [ -e "$foreign/.git" ]
}

@test "list omits a task deleted outside Code" {
  local path
  path=$("$CODE" new demo abandoned)
  rm -rf "$path"

  run "$CODE" list

  [ "$status" -eq 0 ]
  [[ "$output" != *'demo/abandoned'* ]]
  [[ "$output" != *"$path"* ]]

  run "$CODE" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'stale worktree metadata: demo'* ]]
  [[ "$output" == *"run 'git worktree prune' in $CODE_ROOT/repos/demo"* ]]
}

@test "remove refuses dirty work unless force is explicit" {
  local path
  path=$("$CODE" new demo dirty)
  printf 'change\n' > "$path/change.txt"

  run "$CODE" remove demo/dirty
  [ "$status" -eq 3 ]
  [ -e "$path/.git" ]

  run "$CODE" remove demo/dirty --force
  [ "$status" -eq 0 ]
  [ ! -e "$path" ]
  git -C "$CODE_ROOT/repos/demo" show-ref --verify --quiet refs/heads/dirty
}

@test "new rejects path-like task names" {
  local bad
  for bad in 'feature/auth' '../escape' 'two words' '-flag'; do
    run "$CODE" new demo "$bad"
    [ "$status" -ne 0 ]
  done
}
