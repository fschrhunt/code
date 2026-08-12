# Releasing Workspaces

Merging to `main` runs CI but does not create a release.

## Prepare

1. Put the release version in `VERSION`.
2. Move the reviewed notes from `[Unreleased]` into a matching `## <version>`
   section in `CHANGELOG.md`.
3. Merge the release change and confirm CI passes.

## Publish

Run the protected **release** GitHub Actions workflow with the version and the
confirmation value `release`. It validates the source, creates
`workspaces-<version>.tar.gz` and `SHA256SUMS`, tags `main`, and publishes the
immutable assets.

If validation fails, no tag or release should be created. Never replace an
existing public version; prepare a new version instead.
