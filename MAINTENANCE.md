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
  - `b2b.md`
  - `b2c.md`
  - `contributing.md`
  - `e-invoicing/index.md`
  - `e-invoicing/validation.md`
  - `e-invoicing/invoice-data/document.md`
  - `e-invoicing/invoice-data/line-items.md`
  - `e-invoicing/invoice-data/payment.md`
  - `api-reference/index.md`
  - `api-reference/invoice/index.md`
  - `api-reference/invoice/validation.md`
  - `api-reference/invoice/country.md`
  - `api-reference/invoice/identifiers.md`
  - `api-reference/invoice/references.md`
  - `api-reference/line-items/unit.md`
  - `api-reference/components.md`
  - `api-reference/tax.md`
  - `api-reference/theme/index.md`
  - `api-reference/theme/layouts.md`
  - `api-reference/theme/parts.md`
  - `api-reference/locale/index.md`
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
| `typst.toml`            | `version = "X.Y.Z"`                    | `version = "0.5.0"`   |
| `src/loom-wrapper.typ`  | `#let loom-key = <invoice-pro:X.Y.Z>`  | `<invoice-pro:0.5.0>` |
| `README.md`             | `#import "@preview/invoice-pro:X.Y.Z"` | 3 import statements   |
| `template/invoice.typ`  | `#import "@preview/invoice-pro:X.Y.Z"` | 1 import statement    |
| `docs/docs/**/*.md`     | `#import "@preview/invoice-pro:X.Y.Z"` | ~36 import statements |
| `docs/DOCUMENTATION.md` | Version column in registry tables      | All `0.X.Y` entries   |

---

## Theme Figures

The figures of the theme documentation (`docs/static/img/themes/`) and of the theming concept (`docs/concepts/theming-api/figures/`) are rendered from the fixtures of the tests, so they show what the current code draws. Rebuild them when a change alters what a preset, a layout, the draft feedback or the proof overlay looks like, and when a version bump changes a preset's appearance on purpose.

### Checklist

- [ ] Run `./scripts/theme-figures` from the repository root. It renders the pages with `tools/figures/pages.typ` into `build/figures/pages/`, composes the labelled sheets with `tools/figures/sheets.typ`, and writes both figure directories (about 40 seconds).
- [ ] Look at every changed figure before committing it, as with a tytanic reference image. A figure that changed without a visual change in the code points to a changed fixture or font.
- [ ] Update a caption when the figure says something different now: the captions of the sheets are in `tools/figures/sheets.typ`, the alt texts in the pages that show them (`docs/docs/api-reference/theme/`, `docs/docs/api-reference/invoice/validation.md`, `docs/concepts/theming-api/README.md` and the `README.md` of the repository, which links the published `fig-presets.png`).

The script needs Typst (`$TYPST_BIN`, default `typst`) with Liberation Sans installed, which the presets use for body text (without it, they fall back to an embedded font and the figures differ), and Python 3 with Pillow (`$PYTHON`, default `python3`), which reduces each sheet to 256 colours. The invoices are dated 22 September 2026 unless `FIGURES_DATE_EPOCH` sets another date, so a rebuild without changes gives the same figures.

### Files Reference

| File                                                        | Contains                                                                                                        |
| :---------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------- |
| `scripts/theme-figures`                                     | the pages to render, their resolution, the sheets and where each figure goes                                    |
| `tools/figures/pages.typ`                                   | one invoice per compilation (`--input page=gallery\|matrix\|proof\|draft\|..`)                                  |
| `tools/figures/sheets.typ`                                  | the sheets: titles, captions and the arrangement of the pages                                                   |
| `tests/theme/body.typ`                                      | the identical data of the preset, layout, proof and matrix figures (with the brand of `tests/theme/matrix.typ`) |
| `tests/theme/gallery/`                                      | the industry invoices of the ten presets (the preset pages and `fig-presets-industry`)                          |
| `tests/theme/draft.typ`, `stationery.typ`, `acme-theme.typ` | the draft, the stationery modes and the third-party layout                                                      |
