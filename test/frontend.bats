#!/usr/bin/env bats
# The public CLI is deliberately small and uses stable task identities.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
  export WORKFRAME_BACKEND=0
}

@test "setup accepts an explicit root for automation" {
  local root="$BATS_TEST_TMPDIR/workframe-store"
  run "$WORKFRAME" setup --root "$root" --org example
  [ "$status" -eq 0 ]
  [ "$output" = "initialized: $root" ]
  [ -d "$root/repos" ]
  [ -f "$root/WORKFRAME.md" ]
  grep -q '^default_org = example$' "$root/system/config/workframe.conf"
  [ "$(cat "$XDG_CONFIG_HOME/workframe/root")" = "$root" ]
}

@test "setup requires a root without an interactive terminal" {
  run "$WORKFRAME" setup
  [ "$status" -ne 0 ]
  [[ "$output" == *'setup --root <path>'* ]]
}

@test "public lifecycle uses repo/task and machine-readable inspection" {
  run "$WORKFRAME" new demo feature
  [ "$status" -eq 0 ]
  local ws; ws=$(printf '%s\n' "$output" | _workspace_path)

  run "$WORKFRAME" path demo/feature
  [ "$status" -eq 0 ]
  [ "$output" = "$ws" ]

  run "$WORKFRAME" list --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"repo":"demo"'* ]]
  [[ "$output" == *'"task":"feature"'* ]]
  [[ "$output" != *'"city"'* ]]

  run "$WORKFRAME" archive demo/feature --yes
  [ "$status" -eq 0 ]
  run "$WORKFRAME" restore demo feature
  [ "$status" -eq 0 ]
}

@test "public commands reject legacy UI and ambiguous city selectors" {
  "$WORKFRAME" new demo feature >/dev/null
  run "$WORKFRAME" open demo/feature
  [ "$status" -ne 0 ]
  run "$WORKFRAME" path city-name
  [ "$status" -ne 0 ]
  run "$WORKFRAME" dashboard
  [ "$status" -ne 0 ]
}

@test "current and run work from an owned workspace" {
  local ws; ws=$("$WORKFRAME" new demo feature | _workspace_path)
  mkdir -p "$ws/nested"
  run bash -c "cd '$ws/nested' && WORKFRAME_BACKEND=0 WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME' current"
  [ "$status" -eq 0 ]
  [ "$output" = demo/feature ]
  run "$WORKFRAME" run demo/feature -- git rev-parse --show-prefix
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
