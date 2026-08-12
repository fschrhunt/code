# Releasing Workframe

Releases are deliberate. Merging to `main` only runs CI; it never creates a tag,
GitHub release, or Homebrew update.

## Prepare the release

1. Put the release version in `VERSION` and add a matching `## <version>`
   section to `CHANGELOG.md` in a reviewed pull request.
2. Merge that pull request and confirm its `main` CI run passes.
The formula lives in a separate repository and its update needs separate review.
Do not use the old bottles or agent commands as a release test.

## Publish

In GitHub Actions, run **release** with:

- `version`: the exact value in `VERSION`, without `v`;
- `confirm`: `release`.

The protected `release` environment should require maintainer approval. The
workflow checks the version and changelog heading, runs `make check`, creates an
annotated `v<version>` tag on `main`, and publishes a GitHub release using that
changelog section.

If any validation fails, no tag or release is created. Never rerun the workflow
for a version that already has a public tag; make a new version instead.

## Update Homebrew

After the workflow creates `v<version>`, update
`fschrhunt/homebrew-tap/Formula/workframe.rb` in a separate reviewed pull
request:

- set the source URL to
  `https://github.com/fschrhunt/workframe/archive/refs/tags/v<version>.tar.gz`;
- calculate and set the source SHA-256;
- ensure the formula test exercises `workframe setup --root <temporary-path>`
  and `workframe version`.
