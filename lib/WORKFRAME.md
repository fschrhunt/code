# WORKFRAME.md — agent contract

You are operating inside a Workframe-managed Git store. Follow this contract
for all work below this directory.

## Establish context before editing

- Confirm the current working directory and Git branch.
- Work only inside an active path shaped like
  `workspaces/<agent>/<repo>/<city>/`.
- If the current directory is a canonical clone under `repos/`, stop and move
  the task into an isolated worktree.
- Read and follow the current repository's own agent instructions. Instructions
  closer to the code are more specific than this store-level contract.

## Drive Workframe by command

- Run `workframe help --agent` for the full command reference. You can create
  workspaces, clone repositories, and manage their lifecycle directly.
- Use `workframe worktrees` and `workframe repos` when you need to parse the
  store; `workframe list` is formatted for people.
- Use `workframe path <selector>` to resolve a workspace directory. Do not use
  `workframe cd` in a script: a shell integration may wrap it so that it changes
  directory instead of printing.
- Set `WORKFRAME_COLOR=0` or `NO_COLOR=1` for output without ANSI escapes.
- Exit `3` means a command refused because a worktree has uncommitted changes.
  The work is intact — commit it or ask before discarding.

## Work only in the current worktree

- Keep changes scoped to the assigned task.
- Preserve unrelated and pre-existing changes.
- Do not edit or inspect sibling workspaces unless the task explicitly requires
  it.
- Do not move, replace, or delete the worktree's `.git` file.
- Do not modify another worktree or branch to complete the current task.

## Respect store boundaries

- `repos/` contains canonical clones managed by Workframe. Do not implement
  changes there.
- `workspaces/` contains isolated working state. Treat sibling workspaces as
  private.
- `system/` contains Workframe configuration, program files, and operational
  state. Do not place project files there or expose its contents.

## Validate and hand off

- Use the repository's documented build, test, and review commands.
- Do not run destructive lifecycle commands such as `workframe archive
  --force`, `workframe clean --yes`, or `workframe remove` unless the task
  explicitly requires that exact action. Reversible actions — `new`, `clone`,
  `list`, `sync`, `archive` without `--force`, `restore` — need no such
  permission.
- Never recursively delete store, repository, or workspace paths.
- Report the workspace path, branch, validation performed, and any uncommitted
  or unpushed work when handing off.
