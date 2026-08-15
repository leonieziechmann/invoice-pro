---
name: create-release
description: Step-by-step guide for creating a new invoice-pro release, including pre-checks, Docusaurus doc version snapshotting, package packaging, tagging, and patch notes.
---

# Creating a Release for invoice-pro

Follow this workflow to release a new version of `invoice-pro`.

---

## Step 1: Pre-Release Verification

Run the PR precheck to guarantee that formatting, tests, documentation, and ZUGFeRD validations all pass:

```bash
./scripts/check-pr
# or
nix run .#check-pr
```

---

## Step 2: Version Bump

Ensure all version references have been updated following the `bump-version` skill:

```bash
./scripts/check-version <old-version>
```

---

## Step 3: Create Docusaurus Versioned Docs Snapshot

Create a frozen snapshot of the current documentation for the new release:

```bash
# In the docs directory:
cd docs
yarn docusaurus docs:version <version>
# or npm run docusaurus docs:version <version>
cd ..
```

This generates `docs/versioned_docs/version-<version>/` and updates `docs/versions.json`.

---

## Step 4: Verify Release Tarball Packaging

Verify that the release package archive builds cleanly:

```bash
nix build .#release
ls -la result/
```

---

## Step 5: Commit and Create Git Tag

1. Stage and commit all version bump and documentation snapshot changes:
   ```bash
   git add -A
   git commit -m "chore(release): prepare v<version>"
   ```
2. Create annotated tag:
   ```bash
   git tag -a "v<version>" -m "Release v<version>"
   ```
3. Push commit and tag:
   ```bash
   git push origin main
   git push origin "v<version>"
   ```

---

## Step 6: GitHub Actions Release Automation

Pushing the release tag triggers:

- **Publish to Typst Universe**: Automatic PR creation to Typst Packages repository.
- **Release Package Archive**: Builds `invoice-pro-v<version>.tar.gz` and attaches it to the GitHub Release.
