# Shared bats helpers.
#
# WORKFRAME points at the entry script under test. A hermetic backend store is built in
# each test's $BATS_TEST_TMPDIR: a bare "origin" repo plus a canonical clone,
# mimicking the post-`workframe clone` state — no box, no network, no SMB, no TTY.

WORKFRAME="${BATS_TEST_DIRNAME}/../bin/workframe"

# Force the in-process backend and a throwaway data root.
_use_backend_store() {
  export WORKFRAME_BACKEND=1
  export WORKFRAME_COLOR=0
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/store"
  mkdir -p "$WORKFRAME_HOME/repos" "$WORKFRAME_HOME/workspaces" \
    "$WORKFRAME_HOME/system/config" "$WORKFRAME_HOME/system/logs"
  # The task model has no agent registry.
  cat > "$WORKFRAME_HOME/system/config/workframe.conf" <<'EOF'
type = local
editor = cursor
default_org = example
EOF
}

# Create a canonical repo named $1 (default: demo) with an initial commit on main.
_seed_repo() {
  local name="${1:-demo}"
  local origin="$BATS_TEST_TMPDIR/${name}-origin.git"
  local seed="$BATS_TEST_TMPDIR/${name}-seed"
  git init -q --bare "$origin"
  git init -q "$seed"
  git -C "$seed" config user.email t@example.com
  git -C "$seed" config user.name tester
  git -C "$seed" checkout -q -b main
  echo "# $name" > "$seed/README.md"
  git -C "$seed" add -A
  git -C "$seed" commit -qm "init"
  git -C "$seed" remote add origin "$origin"
  git -C "$seed" push -q -u origin main
  # Bare `git init` inherits init.defaultBranch (often master on CI). Point HEAD
  # at main so the subsequent clone does not fail with a dangling remote HEAD.
  git -C "$origin" symbolic-ref HEAD refs/heads/main
  git clone -q "$origin" "$WORKFRAME_HOME/repos/$name"
  git -C "$WORKFRAME_HOME/repos/$name" remote set-head origin -a >/dev/null 2>&1
  git -C "$WORKFRAME_HOME/repos/$name" config worktree.useRelativePaths true
}

# Echo the "workspace:" path from a `workframe new`/`workframe restore` output block.
_workspace_path() { sed -n 's/^workspace: //p'; }
