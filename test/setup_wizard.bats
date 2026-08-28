#!/usr/bin/env bats
# Interactive setup prompts are exercised through a portable Python pseudo-terminal.

load helper

setup() {
  _use_test_root
  PTY_RUNNER="$BATS_TEST_TMPDIR/pty_runner.py"
  cat > "$PTY_RUNNER" <<'PY'
import os, pty, select, sys, time

inputs = sys.argv[1].encode().decode("unicode_escape").encode()
pid, fd = pty.fork()
if pid == 0:
    os.execv(os.environ["CODE"], [os.environ["CODE"], "setup"])

output = bytearray()
sent = False
while True:
    readable, _, _ = select.select([fd], [], [], 0.1)
    if readable:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            ended, status = os.waitpid(pid, 0)
            sys.stdout.buffer.write(output)
            sys.exit(os.waitstatus_to_exitcode(status))
        if not chunk:
            ended, status = os.waitpid(pid, 0)
            sys.stdout.buffer.write(output)
            sys.exit(os.waitstatus_to_exitcode(status))
        output.extend(chunk)
        if not sent and b"Collection root" in output:
            os.write(fd, inputs)
            sent = True
        elif sent and b"Set up this collection?" in output and inputs.startswith(b"\n"):
            # The first newline answered the root prompt; send the remaining answer now.
            remainder = inputs[1:]
            if remainder:
                os.write(fd, remainder)
            inputs = b"x"
    ended, status = os.waitpid(pid, os.WNOHANG)
    if ended:
        while True:
            try:
                output.extend(os.read(fd, 4096))
            except OSError:
                break
        sys.stdout.buffer.write(output)
        sys.exit(os.waitstatus_to_exitcode(status))
    if len(output) > 100000:
        os.kill(pid, 9)
        raise SystemExit("too much output")
PY
}

@test "setup wizard accepts defaults and keeps stdout usable" {
  rm -rf "$CODE_ROOT"
  unset CODE_ROOT
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" CODE="$CODE" \
    python3 "$PTY_RUNNER" '\n\n'

  [ "$status" -eq 0 ]
  [[ "$output" == *'? Collection root ['*'~/Code]:'* ]]
  [[ "$output" == *'Repositories'*"$home/Code/repos"* ]]
  [[ "$output" == *'? Set up this collection? [Y/n]:'* ]]
  [ -d "$home/Code/repos" ]
  [ -d "$home/Code/worktrees" ]
}

@test "setup wizard accepts a custom home-relative root" {
  rm -rf "$CODE_ROOT"
  unset CODE_ROOT
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" CODE="$CODE" \
    python3 "$PTY_RUNNER" '~/Code\n\n'

  [ "$status" -eq 0 ]
  home=$(cd -P "$home" && pwd)
  [[ "$output" == *"Root"*"$home/Code"* ]]
  [ -d "$home/Code/repos" ]
  [ "$(cat "$XDG_CONFIG_HOME/code/root")" = "$home/Code" ]
}

@test "setup wizard cancellation makes no changes" {
  rm -rf "$CODE_ROOT"
  unset CODE_ROOT
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" CODE="$CODE" \
    python3 "$PTY_RUNNER" '\nn\n'

  [ "$status" -ne 0 ]
  [[ "$output" == *'setup cancelled; no changes were made'* ]]
  [ ! -e "$home/Code" ]
}
