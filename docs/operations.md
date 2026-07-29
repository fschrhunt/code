# Operations and releases

This guide covers shared-installation and release safety. It does not authorize
changes to a live deployment.

## Separation of concerns

- Product changes happen in this repository, on a branch, through a PR.
- Development uses test fixtures or a personal local store.
- Shared installation is a separate, explicit post-merge action.
- Agents never merge or deploy unless the user directly authorizes it.

Never patch a mounted `$BOX_ROOT/system/bin/workframe` in place.

## Shared installation contract

A shared profile expects:

```text
$BOX_ROOT/
├── WORKFRAME.md
├── repos/
├── workspaces/
└── system/
    ├── bin/workframe
    ├── config/workframe.conf
    └── logs/
```

Infrastructure values belong in the user config or private deployment overlay,
not in source defaults.

The backend provisions `WORKFRAME.md` from Workframe's shipped template without
overwriting an existing store contract.

## Pre-release checklist

1. Confirm the GitHub issue has a clear problem and acceptance criteria.
2. Review the complete diff against `origin/main`.
3. Run `make check`.
4. Exercise the riskiest lifecycle path against a disposable
   `WORKFRAME_HOME`.
5. Confirm tracked documentation contains no private infrastructure values.
6. Open a PR with `Fixes #<issue>`.
7. Wait for CI and review.

## Workframe 1.5.0 cutover

This release is a fresh start:

- Install the `workframe` executable.
- Initialize a new local or shared Workframe store.
- Configure agent identities, editor, organization shortcut, and shared values.
- Clone the desired canonical repositories.
- Leave pre-existing stores and binaries untouched until a separately approved
  retirement task.

Repository settings and visibility changes happen only after the release PR
merges and its checks pass.

## Public visibility gate

Before changing the repository from private to public:

1. Scan the complete Git history with a dedicated secret scanner using redacted
   output.
2. Review history for private hostnames, addresses, mount paths, organizations,
   credentials, personal data, and proprietary material.
3. Verify the final `main` tree separately.
4. If any sensitive material appears, keep the repository private and open a
   remediation issue.

Do not treat an allowlist as remediation unless the finding has been verified
as a safe fixture.

## Release artifacts

The source of truth for the version is `VERSION`. Help and
`workframe version` must match it. A tag or published release is a deliberate
post-merge action, not part of the coding PR.

See [Contributing](contributing.md) for implementation workflow and
[Workframe 1.5.0](releases/1.5.0.md) for release notes.
