# Security policy

## Supported versions

Security fixes are applied to the latest released minor version of Workframe.
Users should update before reporting behavior that may already be fixed.

| Version | Supported |
|---|---|
| 1.5.x | Yes |
| Earlier versions | No |

## Report a vulnerability

Do not open a public issue for a suspected vulnerability.

Use GitHub's
[private vulnerability reporting](https://github.com/fschrhunt/workframe/security/advisories/new)
to send the maintainers a confidential report. Include:

- the affected Workframe version and platform;
- the smallest safe reproduction;
- the impact and any preconditions;
- suggested remediation, if known.

Remove real credentials, private hostnames, addresses, and user data. Use
clearly fake placeholders in reproductions.

The maintainers will acknowledge a report within seven days, provide an initial
assessment within fourteen days, and coordinate disclosure after a fix is
available. These are targets rather than a service-level agreement.

## Security model

Workframe runs with the invoking user's permissions and manages Git repositories,
worktrees, configuration, and optional shared-store connections. Treat its
configuration and credential seed files as private local state. Review
destructive commands before confirming them, and test automation against a
disposable `WORKFRAME_HOME`.
