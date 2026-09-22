# Shared hermetic fixtures for repository checkouts and worktrees.

CODE="${BATS_TEST_DIRNAME}/../bin/code"

# Use a disposable collection root for every test.
_use_test_root() {
  export CODE_ROOT="$BATS_TEST_TMPDIR/code"
  mkdir -p "$CODE_ROOT"
  CODE_ROOT=$(cd -P "$CODE_ROOT" && pwd)
  export CODE_ROOT
}

# Create a bare origin with one commit on main; print its path.
_make_origin() {
  local name=${1:-demo}
  local origin="$BATS_TEST_TMPDIR/$name-origin.git"
  local seed="$BATS_TEST_TMPDIR/$name-seed"
  git init -q --bare "$origin"
  git init -q "$seed"
  git -C "$seed" config user.email t@example.com
  git -C "$seed" config user.name tester
  git -C "$seed" checkout -q -b main
  printf '# %s\n' "$name" > "$seed/README.md"
  git -C "$seed" add README.md
  git -C "$seed" commit -qm init
  git -C "$seed" remote add origin "$origin"
  git -C "$seed" push -q -u origin main
  git -C "$origin" symbolic-ref HEAD refs/heads/main
  printf '%s' "$origin"
}

# Clone a fixture origin into the collection's repos directory.
_seed_repo() {
  local name=${1:-demo}
  local origin
  origin=$(_make_origin "$name")
  mkdir -p "$CODE_ROOT/repos"
  git clone -q "$origin" "$CODE_ROOT/repos/$name"
  git -C "$CODE_ROOT/repos/$name" config user.email t@example.com
  git -C "$CODE_ROOT/repos/$name" config user.name tester
}
