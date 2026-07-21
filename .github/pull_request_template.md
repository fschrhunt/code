## Summary

- <!-- What changed and why? -->

## Linear

- Issue: DEV-<!-- number --> (required for planned work; omit only for tiny/Renovate PRs)
- Link with a magic word in this PR body, e.g. `Fixes DEV-123` or `Contributes to DEV-123`
- Assignee stays Fischer; agents are delegates only
- Issue must have Why + Acceptance before implementation work

## Test plan

- <!-- What did you run, or why was validation not run? -->
- [ ] `make check` (shellcheck + bats) when code or golden help changed

## Review notes

- Keep the PR focused; call out intentional follow-ups.
- Branch should include the issue id when applicable (Linear copy-branch / `DEV-123-slug`).
- Greptile reviews on the PR — do not file Linear issues for nits unless follow-up is durable.
- Never edit `/Volumes/Agents/system/bin/wt`.
