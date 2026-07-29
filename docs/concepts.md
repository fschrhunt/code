# Core concepts

Workframe is a thin control plane over Git worktrees. It keeps repository
storage predictable while giving every agent and task an isolated directory.

## Store

The store is the root containing canonical clones, active worktrees, and
system data. Local mode defaults to `~/workframe`; `WORKFRAME_HOME` can point a
process at another root.

```text
~/workframe/
├── repos/
├── workspaces/
└── system/
    ├── config/workframe.conf
    └── logs/
```

## Canonical repository

Each managed repository has one canonical clone under `repos/<repo>`. Workframe
uses it to fetch branches and create or remove worktrees. Day-to-day editing
happens in workspaces, not in the canonical clone.

## Workspace

A workspace is a Git worktree under:

```text
workspaces/<agent>/<repo>/<city>
```

The city is a stable folder label chosen when the workspace is created. The
branch remains the durable identity.

## Agent

An agent is a configured identity used as the first branch segment:

```text
<agent>/<feature>
```

For example, `codex/fix-login` belongs to the `codex` identity. Workframe
requires an explicit configured identity and never silently chooses one.

## Selector

Interactive commands can resolve a workspace by:

- Full path
- `repo/feature`
- City label
- Interactive selection when `gum` and a terminal are available

Ambiguous selectors are rejected rather than guessed.

## Archive versus remove

Archive is reversible: it removes the worktree folder and keeps the branch.
Restore recreates the folder. Remove is permanent and has separate branch and
repository forms.

## Local and shared profiles

Local mode executes store operations in-process. Shared mode constructs a
quoted SSH command that executes the backend at
`$BOX_ROOT/system/bin/workframe`, while the frontend uses the mounted path to
open files locally.

Profile choice does not change the public lifecycle commands.

## Safety boundaries

Workframe validates repository names, constrains worktree operations to the
configured store, refuses risky deletion by default, and treats `--force` as
an explicit request to discard otherwise protected state.

Continue with the [workspace lifecycle](guides/workspace-lifecycle.md) or
[configuration reference](reference/configuration.md).
