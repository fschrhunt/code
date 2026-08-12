# Security policy

## Supported versions

Security fixes are applied to the latest released Workspaces version. Users
should update before reporting behavior that may already be fixed.

## Report a vulnerability

Do not open a public issue. Use GitHub's
[private vulnerability reporting](https://github.com/fschrhunt/workspaces/security/advisories/new)
and include the affected version, platform, smallest safe reproduction, impact,
and any suggested remediation. Remove credentials, private paths, hostnames,
and user data.

The maintainers aim to acknowledge reports within seven days and provide an
initial assessment within fourteen days. These are targets, not a service-level
agreement.

## Security model

Workspaces runs with the invoking user's permissions. It clones repositories and
creates or removes linked Git worktrees. Removal requires a worktree-specific
ownership marker and refuses uncommitted changes unless `--force` is explicit.
Test automation against a disposable `WORKSPACES_ROOT`.
