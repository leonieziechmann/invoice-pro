---
name: bump-version
description: Standard operating procedure for bumping invoice-pro version across typst.toml, loom wrapper, documentation, and templates, followed by verification using check-version.
---

# Bumping Version in invoice-pro

Follow this checklist to update version strings across the entire repository.

---

## Files to Update

1. **`typst.toml`**

   ```toml
   version = "X.Y.Z"
   ```

2. **`src/loom-wrapper.typ`**

   ```typ
   #let loom-key = <invoice-pro:X.Y.Z>
   ```

3. **`README.md`**
   - Update all package imports (e.g. `#import "@preview/invoice-pro:X.Y.Z": *`).
   - Update roadmap / changelog highlights if applicable.

4. **`template/invoice.typ`**

   ```typ
   #import "@preview/invoice-pro:X.Y.Z": *
   ```

5. **`docs/docs/` (Current Documentation)**
   Update import statements across all Markdown files:
   - `docs/docs/intro.md`
   - `docs/docs/getting-started.md`
   - `docs/docs/contributing.md`
   - `docs/docs/b2b.md`
   - `docs/docs/b2c.md`
   - `docs/docs/e-invoicing.md`
   - `docs/docs/api-reference/**/*.md`

6. **`docs/DOCUMENTATION.md`**
   - Update version column in the Code Block Registry tables to `X.Y.Z`.

> **Note on Versioned Docs:** Do **NOT** modify files in `docs/versioned_docs/` or `docs/versioned_sidebars/` — those are frozen historical releases.

---

## Verification

Run the version checker to verify no stale references remain:

```bash
# In Nix dev shell or via script:
./scripts/check-version <old-version>

# Or via Nix:
nix run .#check-version -- <old-version>
```

Ensure that:

- Stale references to `<old-version>` are empty (or only in frozen docs).
- Current references to `<new-version>` appear in all expected locations.
