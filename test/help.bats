#!/usr/bin/env bats
# Help golden lock: `workframe help` output must byte-match test/golden/help.txt.
# Intentional UX changes update the golden in the same commit. Also covers `workframe version`.

load helper

@test "help output byte-matches the golden" {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WORKFRAME_HOME/system/config"
  cat > "$WORKFRAME_HOME/system/config/workframe.conf" <<'EOF'
type = local
editor = cursor
default_org = example
agents = cursor
EOF
  WORKFRAME_COLOR=0 "$WORKFRAME" help > "$BATS_TEST_TMPDIR/help.out"
  run diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$BATS_TEST_TMPDIR/help.out"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "bare workframe presents the wizard guide when no terminal is attached" {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WORKFRAME_HOME/system/config"
  printf 'type = local\neditor = cursor\nagents = cursor\n' > "$WORKFRAME_HOME/system/config/workframe.conf"
  run bash -c "WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"interactive workspace wizard"* ]]
  [[ "$output" == *"Start with the outcome you want"* ]]
  [[ "$output" == *"start or continue a workspace"* ]]
  [[ "$output" != *"workframe new"* ]]
}

@test "help header uses the brace logo without adjacent metadata" {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WORKFRAME_HOME/system/config"
  printf 'type = shared\neditor = cursor\nagents = cursor\n' > "$WORKFRAME_HOME/system/config/workframe.conf"
  run bash -c "WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"██  ████  ██"* ]]
  [[ "$output" != *"Workframe v"* ]]
  [[ "$output" != *"Isolated git worktrees"* ]]
  [[ "$output" != *"Shared profile"* ]]
}

@test "help uses the acid brand accent when color is enabled" {
  run bash -c "WORKFRAME_COLOR=1 '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[38;2;240;251;41m'* ]]
  [[ "$output" == *$'\e[48;2;240;251;41m'* ]]
  [[ "$output" != *$'\e[38;2;58;222;161m'* ]]
}

@test "help describes the wizard rather than a command catalogue" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"The home screen guides you to:"* ]]
  [[ "$output" == *"Support:"* ]]
  [[ "$output" != *"START HERE"* ]]
}

@test "help works via -h and --help too" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' -h"
  [ "$status" -eq 0 ]
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' --help"
  [ "$status" -eq 0 ]
}

@test "version prints the VERSION file" {
  run "$WORKFRAME" version
  [ "$status" -eq 0 ]
  [ "$output" = "workframe $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

@test "help points scripts and agents at the automation catalogue" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"workframe help --agent"* ]]
}

@test "help --agent lists the non-interactive interface" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help --agent"
  [ "$status" -eq 0 ]
  # Parity with the wizard: creating workspaces and cloning must be reachable.
  [[ "$output" == *"workframe new <repo> <feature> --agent <name>"* ]]
  [[ "$output" == *"workframe clone"* ]]
  [[ "$output" == *"workframe setup --local"* ]]
  [[ "$output" == *"workframe archive"* ]]
  [[ "$output" == *"workframe restore"* ]]
  [[ "$output" == *"workframe worktrees"* ]]
}

@test "help --agent is reachable by every documented spelling" {
  local form
  for form in --agent -a agent automation; do
    run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help $form"
    [ "$status" -eq 0 ]
    [[ "$output" == *"non-interactive interface"* ]] || {
      echo "help $form did not print the agent catalogue"; false
    }
  done
}

@test "every command in the agent catalogue is a real verb" {
  # The catalogue is the only command reference Workframe ships; it must not
  # drift from the dispatcher.
  local verbs verb count=0
  verbs=$(sed -n '/^else$/,/^fi$/p' "$BATS_TEST_DIRNAME/../bin/workframe" \
    | sed -n 's/^    \([a-z|_]*\)).*/\1/p' | tr '|' '\n' | sort -u)
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help --agent"
  [ "$status" -eq 0 ]
  while read -r verb; do
    [ -n "$verb" ] || continue
    count=$((count + 1))
    printf '%s\n' "$verbs" | grep -qxF "$verb" \
      || { echo "agent catalogue advertises a verb the CLI does not dispatch: $verb"; false; }
  done < <(printf '%s\n' "$output" | sed -n 's/^ *workframe \([a-z]*\).*/\1/p' | sort -u)
  # Guard against the extractor silently matching nothing.
  [ "$count" -ge 12 ]
}
