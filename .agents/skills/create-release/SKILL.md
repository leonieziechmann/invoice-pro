---
name: create-release
description: Step-by-step guide for creating a new invoice-pro release, including pre-checks, version bump, thumbnail regeneration, Docusaurus doc version snapshotting, package packaging, tagging, and patch notes.
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

## Step 3: Regenerate Template Thumbnail

Regenerate the package thumbnail (`thumbnail.png` in the repository root) from the template, rendering only the first page as a PNG:

```bash
typst compile --pages 1 template/invoice.typ thumbnail.png
```

This ensures the template preview in `README.md` and the Typst Universe package listing (configured via `[template] thumbnail = "thumbnail.png"` in `typst.toml`) matches the latest template layout.

---

## Step 4: Create Docusaurus Versioned Docs Snapshot

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

## Step 5: Verify Release Tarball Packaging

Verify that the release package archive builds cleanly:

```bash
nix build .#release
ls -la result/
```

---

## Step 6: Commit and Create Git Tag

1. Stage and commit all version bump, thumbnail, and documentation snapshot changes:
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

## Step 7: GitHub Actions Release Automation

Pushing the release tag triggers:

- **Publish to Typst Universe**: Automatic PR creation to Typst Packages repository.
- **Release Package Archive**: Builds `invoice-pro-v<version>.tar.gz` and attaches it to the GitHub Release.

---

## Step 8: Generate and Provide Release Notes Artifact

Generate structured release notes summarizing all changes, features, and fixes since the previous release. Provide them to the user as an artifact in the chat so they can be easily reviewed, published, or pasted into GitHub Releases.

### Guidelines for Release Notes:

1. **Title Format**: `# Release v<version>: <Key Highlights / Themes> 🚀`
2. **Thematic Grouping**: Categorize changes logically with emoji section headers, for example:
   - `## 🏷️ Components & Document Structure`
   - `## 🌐 Localization & Typography`
   - `## 📄 E-Invoicing & ZUGFeRD Fixes`
   - `## 🧪 Testing, CI & Tooling`
   - `## 📚 Documentation`
   - `## ⚠️ Breaking Changes` (if applicable)
3. **Detail & Attribution**:
   - Each bullet point begins with a bold topic name.
   - Reference PRs (`PR [#XX](https://github.com/leonieziechmann/invoice-pro/pull/XX)`) and Issues (`Issue [#XX](https://github.com/leonieziechmann/invoice-pro/issues/XX)`) where relevant.
   - Provide concise, technically accurate explanations of behavior changes, added parameters, or resolved edge cases.
4. **Artifact Delivery**:
   - Save the notes as a user-facing artifact in the chat (e.g., `release-notes-v<version>.md` with `UserFacing: true`) so the user can easily copy and review the formatted notes.

### Example Structure:

```markdown
# Release vX.Y.Z: Dynamic Reference Signs & Smart Locales 🚀

## 🏷️ Components & Document Structure

- **Dynamic Reference Signs (PR [#26](https://github.com/leonieziechmann/invoice-pro/pull/26)):** Introduced a flexible reference signs component (`references`) tailored for standards like DIN 5008 with Loom context awareness.
- **Dedicated Bank Details Component (PR [#30](https://github.com/leonieziechmann/invoice-pro/pull/30)):** Added a first-class `#bank-details()` component supporting IBAN, optional BIC, and payment references.

## 📄 E-Invoicing & Bug Fixes

- **Mandatory E-Invoicing Validation (Issue [#29](https://github.com/leonieziechmann/invoice-pro/issues/29)):** Enforced strict validation for mandatory EN 16931 fields, preventing Schematron errors in ZUGFeRD XML.
```
