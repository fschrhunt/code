#!/usr/bin/env bats
# CLI self-update — hermetic local Git remotes only, never the network.

load helper

setup() {
  UPDATE_SOURCE="$BATS_TEST_TMPDIR/update-source"
  UPDATE_ORIGIN="$BATS_TEST_TMPDIR/update-origin.git"
  UPDATE_CHECKOUT="$BATS_TEST_TMPDIR/update-checkout"
  UPDATE_HOME="$BATS_TEST_TMPDIR/home"
  UPDATE_STORE="$BATS_TEST_TMPDIR/store"

  mkdir -p "$UPDATE_SOURCE" "$UPDATE_HOME" "$UPDATE_STORE"
  cp -R "$BATS_TEST_DIRNAME/../bin" "$BATS_TEST_DIRNAME/../lib" "$UPDATE_SOURCE/"
  cp "$BATS_TEST_DIRNAME/../VERSION" "$BATS_TEST_DIRNAME/../install.sh" "$UPDATE_SOURCE/"
  git init -q "$UPDATE_SOURCE"
  git -C "$UPDATE_SOURCE" config user.email t@example.com
  git -C "$UPDATE_SOURCE" config user.name tester
  git -C "$UPDATE_SOURCE" checkout -q -b main
  git -C "$UPDATE_SOURCE" add -A
  git -C "$UPDATE_SOURCE" commit -qm "initial product"

  git init -q --bare "$UPDATE_ORIGIN"
  git -C "$UPDATE_SOURCE" remote add origin "$UPDATE_ORIGIN"
  git -C "$UPDATE_SOURCE" push -q -u origin main
  git -C "$UPDATE_ORIGIN" symbolic-ref HEAD refs/heads/main
  git clone -q "$UPDATE_ORIGIN" "$UPDATE_CHECKOUT"

  mkdir -p "$UPDATE_STORE/system/config"
  cat > "$UPDATE_STORE/system/config/workframe.conf" <<'EOF'
type = local
editor = cursor
agents = codex
EOF
  mkdir -p "$UPDATE_STORE/repos/demo" "$UPDATE_STORE/workspaces/codex/demo/city" \
    "$UPDATE_STORE/archived-contexts" "$UPDATE_STORE/system/logs"
  printf 'custom guide\n' > "$UPDATE_STORE/WORKFRAME.md"
  printf 'repo data\n' > "$UPDATE_STORE/repos/demo/sentinel"
  printf 'workspace data\n' > "$UPDATE_STORE/workspaces/codex/demo/city/sentinel"
  printf 'archive data\n' > "$UPDATE_STORE/archived-contexts/sentinel"
}

@test "workframe update fast-forwards the installed checkout" {
  printf '9.9.9\n' > "$UPDATE_SOURCE/VERSION"
  printf 'updated\n' > "$UPDATE_SOURCE/UPDATE-MARKER"
  git -C "$UPDATE_SOURCE" add VERSION UPDATE-MARKER
  git -C "$UPDATE_SOURCE" commit -qm "publish update"
  git -C "$UPDATE_SOURCE" push -q

  run env HOME="$UPDATE_HOME" WORKFRAME_COLOR=0 WORKFRAME_HOME="$UPDATE_STORE" \
    "$UPDATE_CHECKOUT/bin/workframe" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated Workframe 9.9.9"* ]]
  [ "$(cat "$UPDATE_CHECKOUT/UPDATE-MARKER")" = updated ]

  run env HOME="$UPDATE_HOME" WORKFRAME_COLOR=0 WORKFRAME_HOME="$UPDATE_STORE" \
    "$UPDATE_CHECKOUT/bin/workframe" version
  [ "$status" -eq 0 ]
  [ "$output" = "workframe 9.9.9" ]
  [ "$(cat "$UPDATE_STORE/WORKFRAME.md")" = "custom guide" ]
  [ "$(cat "$UPDATE_STORE/repos/demo/sentinel")" = "repo data" ]
  [ "$(cat "$UPDATE_STORE/workspaces/codex/demo/city/sentinel")" = "workspace data" ]
  [ "$(cat "$UPDATE_STORE/archived-contexts/sentinel")" = "archive data" ]
}

@test "workframe update preserves a checkout with local changes" {
  printf 'local change\n' >> "$UPDATE_CHECKOUT/VERSION"

  run env HOME="$UPDATE_HOME" WORKFRAME_COLOR=0 WORKFRAME_HOME="$UPDATE_STORE" \
    "$UPDATE_CHECKOUT/bin/workframe" update
  [ "$status" -ne 0 ]
  [[ "$output" == *"checkout has local changes"* ]]
  [[ "$(cat "$UPDATE_CHECKOUT/VERSION")" == *"local change"* ]]
}

@test "workframe update does not inspect or maintain a shared store" {
  cat > "$UPDATE_STORE/system/config/workframe.conf" <<'EOF'
type = shared
editor = cursor
agents = codex
box_host = unreachable.example
box_user = agents
box_root = /srv/workframe
mount_path = /definitely/not/mounted
share_name = workframe
EOF

  run env HOME="$UPDATE_HOME" WORKFRAME_COLOR=0 WORKFRAME_HOME="$UPDATE_STORE" \
    "$UPDATE_CHECKOUT/bin/workframe" update

  [ "$status" -eq 0 ]
  [[ "$output" == *"already current"* ]]
  [[ "$output" != *"mount"* ]]
  [[ "$output" != *"sync"* ]]
  [[ "$output" != *"doctor"* ]]
  [ "$(cat "$UPDATE_STORE/WORKFRAME.md")" = "custom guide" ]
  [ "$(cat "$UPDATE_STORE/repos/demo/sentinel")" = "repo data" ]
  [ "$(cat "$UPDATE_STORE/workspaces/codex/demo/city/sentinel")" = "workspace data" ]
  [ "$(cat "$UPDATE_STORE/archived-contexts/sentinel")" = "archive data" ]
}

@test "workframe update works while the selected store is unavailable" {
  local missing_store="$BATS_TEST_TMPDIR/unmounted/workframe"
  mkdir -p "$UPDATE_HOME/.config/workframe"
  printf '%s\n' "$missing_store" > "$UPDATE_HOME/.config/workframe/root"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$UPDATE_HOME" WORKFRAME_COLOR=0 \
    "$UPDATE_CHECKOUT/bin/workframe" update

  [ "$status" -eq 0 ]
  [[ "$output" == *"already current"* ]]
  [ ! -e "$missing_store" ]
}
