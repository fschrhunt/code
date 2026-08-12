# Shared hermetic fixtures for ordinary repositories and sibling task worktrees.

WORKSPACES="${BATS_TEST_DIRNAME}/../bin/workspaces"

# Use a disposable collection and configuration directory for every test.
_use_test_root() {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  export WORKSPACES_ROOT="$BATS_TEST_TMPDIR/workspaces"
  mkdir -p "$WORKSPACES_ROOT"
  WORKSPACES_ROOT=$(cd -P "$WORKSPACES_ROOT" && pwd)
  export WORKSPACES_ROOT
}

# Create an origin and clone its main checkout directly into the collection.
_seed_repo() {
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
  git clone -q "$origin" "$WORKSPACES_ROOT/$name"
  git -C "$WORKSPACES_ROOT/$name" config user.email t@example.com
  git -C "$WORKSPACES_ROOT/$name" config user.name tester
  git -C "$WORKSPACES_ROOT/$name" config worktree.useRelativePaths true
}
