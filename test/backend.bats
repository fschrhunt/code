#!/usr/bin/env bats
# Agent worktree lifecycle and destructive-action safety.

load helper

setup() {
  _use_test_root
  _seed_repo demo
}

@test "new creates an agent worktree under worktrees" {
  cd "$CODE_ROOT/repos/demo"
  run "$CODE" new e
  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/e-demo" ]
  [ -e "$output/.git" ]
  # Detached by default: no branch, HEAD at the repository's HEAD.
  [ -z "$(git -C "$output" branch --show-current)" ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git -C "$CODE_ROOT/repos/demo" rev-parse HEAD)" ]
  local git_dir
  git_dir=$(git -C "$output" rev-parse --absolute-git-dir)
  [ -f "$git_dir/code-managed" ]
}

@test "new discovers the repository from the current folder" {
  mkdir -p "$CODE_ROOT/repos/demo/nested"
  cd "$CODE_ROOT/repos/demo/nested"

  run "$CODE" new e

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/e-demo" ]
  [ -e "$output/.git" ]
}

@test "new does not discover a clone outside repos" {
  local origin outside="$BATS_TEST_TMPDIR/outside"
  origin=$(git -C "$CODE_ROOT/repos/demo" remote get-url origin)
  git clone -q "$origin" "$outside"
  cd "$outside"

  run "$CODE" new e

  [ "$status" -ne 0 ]
  [[ "$output" == *"run from $CODE_ROOT/repos/<repo>"* ]]
  [ -z "$(ls "$CODE_ROOT/worktrees" 2>/dev/null)" ]
}

@test "new checks out the repository's current HEAD, detached" {
  cd "$CODE_ROOT/repos/demo"
  printf 'local\n' >> README.md
  git add README.md
  git commit -qm local

  run "$CODE" new e
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git -C "$CODE_ROOT/repos/demo" rev-parse HEAD)" ]
  [ -z "$(git -C "$output" branch --show-current)" ]
}

@test "new reattaches an existing inactive branch" {
  git -C "$CODE_ROOT/repos/demo" branch e-demo
  cd "$CODE_ROOT/repos/demo"

  run "$CODE" new e

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/e-demo" ]
  [ "$(git -C "$output" branch --show-current)" = e-demo ]
}

@test "agent worktrees suffix -1 when the name is occupied" {
  mkdir -p "$CODE_ROOT/worktrees/e-demo"
  cd "$CODE_ROOT/repos/demo"

  run "$CODE" new e

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/e-demo-1" ]
  [ -e "$output/.git" ]
}

@test "parallel agent worktrees have independent working files" {
  local first second
  cd "$CODE_ROOT/repos/demo"
  first=$("$CODE" new e)
  second=$("$CODE" new claude)
  printf 'first\n' > "$first/work.txt"
  printf 'second\n' > "$second/work.txt"

  [ "$(cat "$first/work.txt")" = first ]
  [ "$(cat "$second/work.txt")" = second ]
  [ ! -e "$CODE_ROOT/repos/demo/work.txt" ]
}

@test "agent worktrees reuse the directory after a worktree is removed" {
  local first
  cd "$CODE_ROOT/repos/demo"
  first=$("$CODE" new e)
  run "$CODE" remove "$first"
  [ "$status" -eq 0 ]

  run "$CODE" new e

  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
  # Detached again — no branch carried over from the removed worktree.
  [ -z "$(git -C "$output" branch --show-current)" ]
}

@test "agent worktrees list and remove by name" {
  local path
  cd "$CODE_ROOT/repos/demo"
  path=$("$CODE" new e)

  run "$CODE" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo/e-demo"* ]]

  run "$CODE" remove demo/e-demo
  [ "$status" -eq 0 ]
  [ ! -e "$path" ]
}

@test "remove accepts a bare name" {
  local first second
  cd "$CODE_ROOT/repos/demo"
  first=$("$CODE" new e)
  second=$("$CODE" new e)

  run "$CODE" remove e-demo-1
  [ "$status" -eq 0 ]
  [ ! -e "$second" ]
  [ -e "$first" ]

  run "$CODE" remove e-demo
  [ "$status" -eq 0 ]
  [ ! -e "$first" ]
}

@test "ownership survives branch and Git worktree renames" {
  local original moved
  cd "$CODE_ROOT/repos/demo"
  original=$("$CODE" new e)
  moved="$CODE_ROOT/worktrees/e-demo-moved"
  # A detached worktree has no branch; the agent names one from the work.
  git -C "$original" switch -q -c better-branch
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

@test "a detached worktree moved outside no longer blocks a fresh one" {
  local original outside
  cd "$CODE_ROOT/repos/demo"
  original=$("$CODE" new e)
  outside="$BATS_TEST_TMPDIR/outside"
  git -C "$CODE_ROOT/repos/demo" worktree move "$original" "$outside"

  # A detached worktree carries no branch, so there is no branch conflict to
  # detect against a moved-away worktree: `new` creates a fresh detached
  # worktree at the freed path and leaves the moved one untouched. (The old
  # branch-based refusal is gone with the branch.)
  run "$CODE" new e

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/e-demo" ]
  [ -e "$outside/.git" ]
}

@test "unmarked nested worktrees are ignored and cannot be removed" {
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

@test "unmarked flat worktrees are ignored and cannot be removed" {
  local foreign="$CODE_ROOT/worktrees/manual-demo"
  mkdir -p "$CODE_ROOT/worktrees"
  git -C "$CODE_ROOT/repos/demo" worktree add -q -b manual-demo "$foreign" HEAD

  run "$CODE" list
  [ "$status" -eq 0 ]
  [[ "$output" != *"manual-demo"* ]]

  run "$CODE" remove "$foreign"
  [ "$status" -ne 0 ]
  [ -e "$foreign/.git" ]
}

@test "list omits a worktree deleted outside Code" {
  local path
  cd "$CODE_ROOT/repos/demo"
  path=$("$CODE" new e)
  rm -rf "$path"

  run "$CODE" list

  [ "$status" -eq 0 ]
  [[ "$output" != *'demo/e-demo'* ]]
  [[ "$output" != *"$path"* ]]

  run "$CODE" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'stale worktree metadata: demo'* ]]
  [[ "$output" == *"run 'git worktree prune' in $CODE_ROOT/repos/demo"* ]]
}

@test "remove refuses dirty work unless force is explicit" {
  local path
  cd "$CODE_ROOT/repos/demo"
  path=$("$CODE" new e)
  printf 'change\n' > "$path/change.txt"

  run "$CODE" remove demo/e-demo
  [ "$status" -eq 3 ]
  [ -e "$path/.git" ]

  run "$CODE" remove demo/e-demo --force
  [ "$status" -eq 0 ]
  [ ! -e "$path" ]
}

@test "new rejects invalid agent names and wrong arity" {
  cd "$CODE_ROOT/repos/demo"
  local bad
  for bad in 'feature/auth' '../escape' 'two words' '-flag' 'demo fix-login'; do
    run "$CODE" $bad
    [ "$status" -ne 0 ]
  done
  [ -z "$(ls "$CODE_ROOT/worktrees" 2>/dev/null)" ]
}
