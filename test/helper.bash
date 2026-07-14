# Shared bats helpers.
#
# WT points at the entry script under test. A hermetic backend store is built in
# each test's $BATS_TEST_TMPDIR: a bare "origin" repo plus a canonical clone,
# mimicking the post-`wt clone` state — no box, no network, no SMB, no TTY.

WT="${BATS_TEST_DIRNAME}/../bin/wt"

# Force the in-process backend and a throwaway data root.
_use_backend_store() {
  export WT_BACKEND=1
  export WT_COLOR=0
  export WT_HOME="$BATS_TEST_TMPDIR/store"
  mkdir -p "$WT_HOME/repos" "$WT_HOME/workspaces" "$WT_HOME/system/logs"
  # Seed a managed agent list — no silent DEFAULT_AGENT; `new` requires a configured name.
  cat > "$WT_HOME/config" <<'EOF'
type = local
editor = cursor
default_org = example
agents = claude, codex, cursor, grok, devin, opencode
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
  git clone -q "$origin" "$WT_HOME/repos/$name"
  git -C "$WT_HOME/repos/$name" remote set-head origin -a >/dev/null 2>&1
  git -C "$WT_HOME/repos/$name" config worktree.useRelativePaths true
}

# Echo the "workspace:" path from a `wt new`/`wt restore` output block.
_workspace_path() { sed -n 's/^workspace: //p'; }
