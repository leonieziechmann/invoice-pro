# Maintenance Guide

This document describes repetitive maintenance tasks that cannot be easily automated. Each section includes a checklist to ensure nothing is missed.

---

## Version Bump

When releasing a new version, the version string must be updated in multiple locations across the codebase. Use the checklist below and perform a final search to catch any missed references.

### Checklist

- [ ] **`typst.toml`** — Update the `version` field
- [ ] **`src/loom-wrapper.typ`** — Update the `loom-key` label (e.g., `<invoice-pro:X.Y.Z>`)
- [ ] **`README.md`** — Update all `@preview/invoice-pro:X.Y.Z` import strings (3 occurrences)
- [ ] **`template/invoice.typ`** — Update the import version
- [ ] **`docs/docs/` (current docs)** — Update all `@preview/invoice-pro:X.Y.Z` imports across:
  - `intro.md`
  - `getting-started.md`
  - `contributing.md`
  - `api-reference/index.md`
  - `api-reference/invoice.md`
  - `api-reference/components.md`
  - `api-reference/tax.md`
  - `api-reference/theme.md`
  - `api-reference/locale/custom.md`
  - `api-reference/locale/base.md`
- [ ] **`docs/DOCUMENTATION.md`** — Update all version numbers in the Code Block Registry tables
- [ ] **Docusaurus versioned docs** — Create a new versioned snapshot if needed (`docs/versioned_docs/version-X.Y.Z/`). Do **not** manually edit old versioned docs — they are frozen snapshots.

### Verification

After updating, use the `check-version` command available in the Nix dev shell. It reads the current version from `typst.toml` automatically:

```bash
# Check for stale references to an old version
check-version 0.3.0
```

This searches all `.typ`, `.md`, and `.toml` files while excluding Docusaurus-generated directories. It will report any remaining old version references and list all current version references.

You can also run it outside the dev shell via:

```bash
nix run .#check-version -- 0.3.0
```

> **Note:** Files under `docs/versioned_docs/` and other Docusaurus-generated directories (`build/`, `node_modules/`, `.docusaurus/`, `versioned_sidebars/`) are excluded from these checks. Versioned docs are intentionally frozen at their release version and should **not** be updated.

### Files Reference

| File                    | What to change                         | Example               |
| :---------------------- | :------------------------------------- | :-------------------- |
| `typst.toml`            | `version = "X.Y.Z"`                    | `version = "0.4.0"`   |
| `src/loom-wrapper.typ`  | `#let loom-key = <invoice-pro:X.Y.Z>`  | `<invoice-pro:0.4.0>` |
| `README.md`             | `#import "@preview/invoice-pro:X.Y.Z"` | 3 import statements   |
| `template/invoice.typ`  | `#import "@preview/invoice-pro:X.Y.Z"` | 1 import statement    |
| `docs/docs/**/*.md`     | `#import "@preview/invoice-pro:X.Y.Z"` | ~15 import statements |
| `docs/DOCUMENTATION.md` | Version column in registry tables      | All `0.X.Y` entries   |
