# Releasing Workframe

Releases are deliberate. Merging to `main` only runs CI; it never creates a tag
or GitHub release.

## Prepare the release

1. Put the release version in `VERSION` and add a matching `## <version>`
   section to `CHANGELOG.md` in a reviewed pull request.
2. Merge that pull request and confirm its `main` CI run passes.
3. Confirm the protected GitHub `release` environment requires maintainer
   approval.

## Publish

In GitHub Actions, run **release** with:

- `version`: the exact value in `VERSION`, without `v`;
- `confirm`: `release`.

The workflow checks the version and changelog heading, runs `make check`, creates
a verified versioned source archive with `SHA256SUMS`, creates an annotated
`v<version>` tag on `main`, and publishes the archive, checksum, and changelog
section as a GitHub release. The public installer downloads only those immutable
release assets.

If validation fails, no tag or release is created. Never rerun the workflow for
a version that already has a public tag; make a new version instead.
