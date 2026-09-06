# Concepts

## Base checkout first

A collection keeps repository checkouts and agent worktrees in separate folders:

```text
<root>/repos/e/
<root>/worktrees/e-e/
<root>/worktrees/claude-e/
```

`repos/e/` is a normal checkout, usually kept on its default branch. It can be
created by `code clone` or ordinary `git clone`; Code discovers base
checkouts from `repos/` rather than maintaining an index. It is the place to
select the repository and create worktrees. Automated editing belongs in a
worktree, not in this base checkout.

## Agent workflow

A second terminal or agent session does not isolate files. Before editing, run:

```bash
cd <root>/repos/e
path=$(code new e)
cd "$path"
```

`new` takes one argument: the agent name, such as `e`, `pi`, `claude`, or
`codex`. It discovers the base checkout containing the current directory,
names the folder and branch `<agent>-<repo>` — `e-e` when the agent `e` works
on the repository `e` — and prints the authoritative path. An occupied name
suffixes `-1`, `-2`, and so on. An inactive branch of the same name is
reattached, so removing a worktree and creating it again lands on the same
branch.

Do not create worktrees with ordinary filesystem commands or place them in
`repos/`. The separate hierarchies keep the collection readable and make the
agent/repository relationship explicit.

## Worktree ownership

Code places a marker in the linked worktree's private Git administrative
directory. Lifecycle commands require all of the following:

- the checkout is recorded by its repository as a Git worktree;
- it lives beneath `worktrees/`;
- its private ownership marker exists.

A path pattern or branch name alone is never treated as ownership. Manually
created and third-party worktrees are neither listed nor removed. If a managed
worktree folder is manually deleted, it is no longer listed; `code doctor`
reports the stale Git record until ordinary `git worktree prune` removes it.
