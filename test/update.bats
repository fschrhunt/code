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

  cat > "$UPDATE_STORE/config" <<'EOF'
type = local
editor = cursor
agents = codex
EOF
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
}

@test "workframe update preserves a checkout with local changes" {
  printf 'local change\n' >> "$UPDATE_CHECKOUT/VERSION"

  run env HOME="$UPDATE_HOME" WORKFRAME_COLOR=0 WORKFRAME_HOME="$UPDATE_STORE" \
    "$UPDATE_CHECKOUT/bin/workframe" update
  [ "$status" -ne 0 ]
  [[ "$output" == *"checkout has local changes"* ]]
  [[ "$(cat "$UPDATE_CHECKOUT/VERSION")" == *"local change"* ]]
}
