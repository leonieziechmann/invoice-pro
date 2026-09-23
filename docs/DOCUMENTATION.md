# Documentation Maintenance Guide

This document tracks all code sections in the documentation and their maintenance status. It serves as the single source of truth for ensuring documentation code examples remain correct and tested.

## Key Rules

1. **Every non-trivial code block** must be listed in the registry below.
2. **Code blocks with version numbers** (e.g., `@preview/invoice-pro:0.4.2`) must be flagged with the version so they can be updated during releases.
3. **When adding a new code section**, register it here and — if possible — create a corresponding test under `tests/docs/`. See [TESTING.md](/tests/TESTING.md) for test setup instructions.
4. **Discrepancy resolution:** When docs and tests diverge, take syntax from the test and structure from the docs. See [TESTING.md](/tests/TESTING.md) for the full rule.
5. **Formatting:** Typst code blocks that start with `#` or `//` are typstyle-formatted, so their tests can contain them verbatim.

---

## Code Block Registry

All code sections in `docs/docs/` and the `README.md`, listed by file. Each entry includes:

- **Code ID** — a short identifier for the code block within the file
- **Description** — what the example demonstrates
- **Version** — if the block contains an import with a version number, it is listed here
- **Test** — the corresponding test directory under `tests/`, or `—` if none exists

Tests of blocks that elide the invoice header (`// sender: .., recipient: .., invoice-nr: ..` or `// ...`) put `..party` from `tests/docs/prelude.typ` in its place, and blocks without line items are followed by `body()` from the same file.

### `intro.md`

| Code ID        | Description                                         | Version | Test                  | Notes |
| :------------- | :-------------------------------------------------- | :------ | :-------------------- | :---- |
| `quick-glance` | Full invoice with items, discount, and bank details | `0.4.2` | `docs/intro-minimal/` |       |

### `getting-started.md`

| Code ID         | Description                                      | Version | Test                            | Notes                             |
| :-------------- | :----------------------------------------------- | :------ | :------------------------------ | :-------------------------------- |
| `import`        | Package import statement                         | `0.4.2` | —                               | Trivial one-liner, no test needed |
| `nix-run`       | Compile with Nix without installation            | —       | —                               | Bash command, not Typst           |
| `first-invoice` | Minimal invoice with items and tax configuration | `0.4.2` | `docs/getting-started-minimal/` |                                   |
| `choose-look`   | Another preset with a brand color                | —       | `docs/getting-started-look/`    |                                   |

### `e-invoicing.md`

| Code ID              | Description                                   | Version | Test                         | Notes                                       |
| :------------------- | :-------------------------------------------- | :------ | :--------------------------- | :------------------------------------------ |
| `attach-internals`   | How the core attaches `factur-x.xml`          | —       | —                            | Illustration of internal code, not runnable |
| `compile-a3b`        | Compile command with PDF/A-3b                 | —       | —                            | Bash command, not Typst                     |
| `city-dict`          | City and post code as a dictionary            | —       | —                            | Snippet (partial), no test needed           |
| `seller-contact`     | Seller contact (BG-6) on the sender           | —       | —                            | Snippet (partial), no test needed           |
| `buyer-reference`    | Buyer reference / Leitweg-ID on the recipient | —       | —                            | Snippet (partial), no test needed           |
| `electronic-address` | Manual electronic address (EAS scheme)        | —       | —                            | Snippet (partial), no test needed           |
| `unit-builder`       | Unit from the `unit` module                   | —       | —                            | Trivial one-liner                           |
| `unit-dict`          | Unit as a dictionary with a UN/ECE code       | —       | —                            | Trivial one-liner                           |
| `complete-example`   | Full EN 16931 / XRechnung invoice             | `0.4.2` | `docs/e-invoicing-complete/` |                                             |

### `b2b.md`

| Code ID          | Description                                            | Version | Test                       | Notes |
| :--------------- | :----------------------------------------------------- | :------ | :------------------------- | :---- |
| `national`       | National B2B invoice with register and management keys | `0.4.2` | `docs/b2b-national/`       |       |
| `reverse-charge` | Cross-border B2B invoice with reverse charge           | `0.4.2` | `docs/b2b-reverse-charge/` |       |

### `b2c.md`

| Code ID     | Description                                 | Version | Test                  | Notes |
| :---------- | :------------------------------------------ | :------ | :-------------------- | :---- |
| `national`  | National B2C invoice with gross prices      | `0.4.2` | `docs/b2c-national/`  |       |
| `small-biz` | B2C invoice under the small business scheme | `0.4.2` | `docs/b2c-small-biz/` |       |

### `contributing.md`

| Code ID      | Description                              | Version | Test | Notes                    |
| :----------- | :--------------------------------------- | :------ | :--- | :----------------------- |
| `dev-shell`  | Nix development shell commands           | —       | —    | Bash commands, not Typst |
| `dev-import` | Import snippet showing package injection | `0.4.2` | —    | Trivial snippet          |
| `pre-commit` | Pre-commit run command                   | —       | —    | Bash command, not Typst  |

### `api-reference/index.md`

| Code ID     | Description                                                             | Version | Test                        | Notes |
| :---------- | :---------------------------------------------------------------------- | :------ | :-------------------------- | :---- |
| `blueprint` | Full architectural blueprint with items, payment terms, bank, signature | `0.4.2` | `docs/api-index-blueprint/` |       |

### `api-reference/invoice/index.md`

| Code ID               | Description                                         | Version | Test                        | Notes                             |
| :-------------------- | :-------------------------------------------------- | :------ | :-------------------------- | :-------------------------------- |
| `sender-recipient`    | Sender/recipient dictionaries with register keys    | —       | `docs/api-invoice-parties/` | Wrapped in a show rule            |
| `theme`               | Theme parameter with a brand and an explicit layout | —       | `docs/api-invoice-theme/`   | Wrapped in a show rule            |
| `references-preset`   | References as a preset package                      | —       | —                           | Snippet (partial), no test needed |
| `references-builders` | References as builder functions                     | —       | —                           | Snippet (partial), no test needed |
| `references-array`    | References as array of tuples                       | —       | —                           | Snippet (partial), no test needed |
| `references-dict`     | References as dictionary                            | —       | —                           | Snippet (partial), no test needed |
| `compile-a3b`         | Compile command with PDF/A-3b                       | —       | —                           | Bash command, not Typst           |
| `zugferd-example`     | Show rule with the `en16931` profile                | —       | `docs/api-invoice-zugferd/` | Followed by `body()`              |
| `minimal-config`      | Minimal valid configuration with a single item      | `0.4.2` | `docs/api-invoice-minimal/` |                                   |

### `api-reference/invoice/validation.md`

| Code ID         | Description                                      | Version | Test                                  | Notes                                               |
| :-------------- | :----------------------------------------------- | :------ | :------------------------------------ | :-------------------------------------------------- |
| `draft`         | Draft with a missing number and address, ZUGFeRD | `0.4.2` | `docs/api-invoice-validation-draft/`  | Renders the draft and the report page               |
| `cli`           | `--input invoice-pro-validation` commands        | —       | —                                     | Bash commands, not Typst                            |
| `strict-output` | Message of the draft example under `strict`      | —       | `docs/api-invoice-validation-strict/` | Asserts the message with `catch` and renders it     |
| `locale-patch`  | Custom inline marker through a locale patch      | —       | `docs/api-invoice-validation-locale/` | The test sets `invoice-nr: none` to show the marker |

### `api-reference/invoice/country.md`

| Code ID         | Description                             | Version | Test | Notes                                     |
| :-------------- | :-------------------------------------- | :------ | :--- | :---------------------------------------- |
| `country-usage` | Country configurations for both parties | `0.4.2` | —    | ⚠️ Snippet with `// ...`; not implemented |
| `country-with`  | Custom country name via `.with`         | —       | —    | Snippet (let binding), no test needed     |

### `api-reference/invoice/references.md`

| Code ID             | Description                                    | Version | Test | Notes                                     |
| :------------------ | :--------------------------------------------- | :------ | :--- | :---------------------------------------- |
| `import`            | Import of the `references` module              | `0.4.2` | —    | Trivial one-liner                         |
| `preset-b2b`        | `preset-b2b()` and its expansion               | —       | —    | Snippet (partial), no test needed         |
| `preset-b2g`        | `preset-b2g()` and its expansion               | —       | —    | Snippet (partial), no test needed         |
| `preset-project`    | `preset-project()` and its expansion           | —       | —    | Snippet (partial), no test needed         |
| `preset-din-5008`   | `preset-din-5008()` and its expansion          | —       | —    | Snippet (partial), no test needed         |
| `builder-overrides` | Builder functions with custom labels or values | —       | —    | Snippet (partial), no test needed         |
| `usage-preset`      | Show rule with a preset                        | —       | —    | ⚠️ Snippet with `// ...`; not implemented |
| `usage-builders`    | Show rule with builder functions               | —       | —    | ⚠️ Snippet with `// ...`; not implemented |
| `usage-dict`        | Show rule with a dictionary of builders        | —       | —    | ⚠️ Snippet with `// ...`; not implemented |

### `api-reference/line-items/index.md`

| Code ID            | Description                               | Version | Test | Notes                                |
| :----------------- | :---------------------------------------- | :------ | :--- | :----------------------------------- |
| `group-subtotal`   | Group without subtotal                    | —       | —    | Snippet (partial), no test needed    |
| `group-cascade`    | Group with cascading tax and unit         | —       | —    | Snippet (partial), no test needed    |
| `nested-numbering` | Hierarchical position numbering           | —       | —    | ⚠️ Needs an invoice; not implemented |
| `prepayment`       | Prepayments (absolute, dated, percentage) | —       | —    | ⚠️ Needs an invoice; not implemented |

### `api-reference/line-items/unit.md`

| Code ID      | Description                                | Version | Test | Notes                                     |
| :----------- | :----------------------------------------- | :------ | :--- | :---------------------------------------- |
| `unit-usage` | Units from the `unit` module in a document | `0.4.2` | —    | ⚠️ Snippet with `// ...`; not implemented |
| `unit-dict`  | Structure of a resolved unit               | —       | —    | Data structure, not runnable              |

### `api-reference/components.md`

| Code ID                 | Description                                           | Version | Test                         | Notes                                                               |
| :---------------------- | :---------------------------------------------------- | :------ | :--------------------------- | :------------------------------------------------------------------ |
| `payment-terms-default` | Default prompt payment                                | —       | —                            | Trivial one-liner                                                   |
| `payment-terms-days`    | Relative deadline (14 days)                           | —       | —                            | Trivial one-liner                                                   |
| `payment-terms-date`    | Fixed deadline date                                   | —       | —                            | Trivial one-liner                                                   |
| `apply-bulk-tax`        | Apply block wrapping items with shared lower tax rate | `0.4.2` | `docs/api-components-apply/` | The test places the block in `line-items`                           |
| `info-usage`            | `info` motifs in body text                            | `0.4.2` | `docs/api-components-info/`  | `info.due-date` and `info.iban` currently render empty in body text |
| `info-dynamic`          | `info.dynamic` path queries                           | —       | `docs/api-components-info/`  | Same test as `info-usage`                                           |

### `api-reference/tax.md`

| Code ID          | Description                         | Version | Test | Notes                                   |
| :--------------- | :---------------------------------- | :------ | :--- | :-------------------------------------- |
| `reverse-charge` | Reverse-charge tax usage on an item | `0.4.2` | —    | Snippet only (no full document context) |
| `custom-tax`     | Custom tax category with `tax.new`  | `0.4.2` | —    | Snippet only (let binding)              |

### `api-reference/theme/index.md`

| Code ID       | Description                                       | Version | Test                          | Notes                             |
| :------------ | :------------------------------------------------ | :------ | :---------------------------- | :-------------------------------- |
| `quick-start` | `theme.classic` with a brand, a logo and no marks | `0.4.2` | `docs/api-theme-quick-start/` | Logo fixture `logo.svg`           |
| `passing`     | The forms of passing a theme                      | —       | `docs/api-theme-passing/`     | The test also resolves every form |
| `pick-preset` | Picking a preset by name from `--input`           | —       | `docs/api-theme-pick-preset/` | Renders the default (`classic`)   |

### `api-reference/theme/customization.md`

| Code ID      | Description                                              | Version | Test                               | Notes                             |
| :----------- | :------------------------------------------------------- | :------ | :--------------------------------- | :-------------------------------- |
| `helpers`    | Several `theme.custom` helpers in one code block         | —       | `docs/api-theme-custom-helpers/`   |                                   |
| `brand`      | `brand()` with accent, fonts and logo                    | —       | `docs/api-theme-custom-brand/`     | Logo fixture `logo.svg`           |
| `tokens`     | Token patches with derivations                           | —       | `docs/api-theme-custom-tokens/`    |                                   |
| `options`    | Option patches for table, totals, title, page number, QR | —       | `docs/api-theme-custom-options/`   |                                   |
| `checks`     | `checks(min-contrast:, pairs:)` with a light brand color | —       | `docs/api-theme-custom-checks/`    |                                   |
| `brand-toml` | Brand file in TOML                                       | —       | `docs/api-theme-custom-from-data/` | Fixture `brand.toml`              |
| `from-data`  | `from-data` with an `assets` function                    | —       | `docs/api-theme-custom-from-data/` | Fixtures `brand.toml`, `logo.svg` |

### `api-reference/theme/layouts.md`

| Code ID       | Description                                           | Version | Test                                  | Notes                                        |
| :------------ | :---------------------------------------------------- | :------ | :------------------------------------ | :------------------------------------------- |
| `region`      | `layout: auto` for an Austrian sender                 | `0.4.2` | `docs/api-theme-layouts-region/`      | Asserts `din-5008-b`                         |
| `for-region`  | A region function from a job file                     | —       | `docs/api-theme-layouts-for-region/`  | Asserts the region mapping                   |
| `areas`       | Area patches: logo right, references moved, no header | —       | `docs/api-theme-layouts-areas/`       | Logo fixture `logo.svg`                      |
| `derive`      | A company layout with `theme.layout.derive`           | —       | `docs/api-theme-layouts-derive/`      |                                              |
| `stationery`  | The three stationery modes from one input             | —       | `docs/api-theme-layouts-stationery/`  | Renders the default mode `pdf`; SVG fixtures |
| `proof`       | Envelopes and the print proof                         | —       | `docs/api-theme-layouts-proof/`       | The test switches the proof on by default    |
| `roll`        | An 80 mm thermal-roll receipt                         | `0.4.2` | `docs/api-theme-layouts-roll/`        |                                              |
| `din-listing` | DIN 5008 form A and B as data                         | —       | `docs/api-theme-layouts-din-listing/` | Asserts equality with the shipped layouts    |
| `qr-bill`     | Swiss layout with the QR-bill zone (0.5.x preview)    | —       | `docs/api-theme-layouts-qr-bill/`     | The test switches the zone on by default     |

### `api-reference/theme/parts.md`

| Code ID          | Description                                      | Version | Test                                   | Notes                                           |
| :--------------- | :----------------------------------------------- | :------ | :------------------------------------- | :---------------------------------------------- |
| `contract`       | Replace, wrap and eject parts                    | —       | `docs/api-theme-parts-contract/`       |                                                 |
| `payment-terms`  | A payment-terms part built from its view         | —       | `docs/api-theme-parts-payment-terms/`  |                                                 |
| `footer-content` | Content cells with `info` motifs in the footer   | —       | `docs/api-theme-parts-footer-content/` |                                                 |
| `custom-area`    | A prefixed custom part in a new foreground area  | —       | `docs/api-theme-parts-custom-area/`    |                                                 |
| `themed`         | `themed` scopes for a group and the bank details | —       | `docs/api-theme-parts-themed/`         | The test adds the show rule                     |
| `package-lib`    | A zero-import theme package                      | —       | `docs/api-theme-parts-package/`        | The package is the local file `acme-theme.typ`  |
| `package-usage`  | Using the package with a preset                  | `0.4.2` | `docs/api-theme-parts-package/`        |                                                 |
| `package-ci`     | `theme.resolve` in the package CI                | —       | `docs/api-theme-parts-package/`        |                                                 |
| `resolve`        | `theme.resolve` assertions                       | —       | `docs/api-theme-parts-resolve/`        | The test also renders an invoice with the theme |

### `api-reference/theme/migration.md`

| Code ID  | Description                      | Version | Test                        | Notes                                |
| :------- | :------------------------------- | :------ | :-------------------------- | :----------------------------------- |
| `before` | A 0.4 document                   | —       | —                           | 0.4 code, intentionally not compiled |
| `after`  | The same document in 0.5         | —       | `docs/api-theme-migration/` |                                      |
| `error`  | Message of a 0.4 theme parameter | —       | —                           | Plain text                           |

### `api-reference/locale/index.md`

| Code ID            | Description                                         | Version | Test                                  | Notes                                       |
| :----------------- | :-------------------------------------------------- | :------ | :------------------------------------ | :------------------------------------------ |
| `locale-usage`     | Setting locale in show rule                         | —       | —                                     | Trivial snippet                             |
| `locale-customize` | Locale customization with `locale.custom` overrides | `0.4.2` | `docs/api-locale-customize/`          | Two pages, to show the page label           |
| `currency-format`  | Custom currency formatting override                 | —       | `docs/api-locale-currency/`           |                                             |
| `validation-texts` | Custom validation marker through a locale patch     | —       | `docs/api-invoice-validation-locale/` | Same code as `validation.md` `locale-patch` |

### `api-reference/locale/custom.md`

| Code ID       | Description                                 | Version | Test                         | Notes                          |
| :------------ | :------------------------------------------ | :------ | :--------------------------- | :----------------------------- |
| `pl-language` | Polish language dictionary definition       | `0.4.2` | `docs/api-locale-custom-pl/` | File `lang/pl.typ` of the test |
| `pl-region`   | Polish region builder function              | `0.4.2` | `docs/api-locale-custom-pl/` | File `region/pl.typ`           |
| `pl-factory`  | Building locale with `build-locale` factory | `0.4.2` | `docs/api-locale-custom-pl/` | File `lib.typ`                 |
| `pl-usage`    | Using the custom locale in a document       | `0.4.2` | `docs/api-locale-custom-pl/` | `test.typ`                     |

### `api-reference/locale/base.md`

| Code ID           | Description                                     | Version | Test                             | Notes |
| :---------------- | :---------------------------------------------- | :------ | :------------------------------- | :---- |
| `schema-override` | Schema inspection and partial language override | `0.4.2` | `docs/api-locale-base-override/` |       |

### `README.md`

| Code ID       | Description                      | Version | Test                           | Notes                   |
| :------------ | :------------------------------- | :------ | :----------------------------- | :---------------------- |
| `install`     | Package import statement         | `0.4.2` | —                              | Trivial one-liner       |
| `basic-usage` | Full invoice                     | `0.4.2` | `docs/readme-getting-started/` |                         |
| `theming`     | A preset with a brand and a logo | —       | `docs/readme-theming/`         | Logo fixture `logo.svg` |
| `nix-run`     | Compile with Nix                 | —       | —                              | Bash command, not Typst |
| `dev-shell`   | Nix development shell            | —       | —                              | Bash command, not Typst |
| `dev-import`  | Import in the development shell  | `0.4.2` | —                              | Trivial one-liner       |
| `check-pr`    | Pull request checks              | —       | —                              | Bash command, not Typst |

The package template `template/invoice.typ` is compiled by the tytanic template test (`@template`) and validated by `scripts/validate-all-zugferd`.

---

## Version Bump Checklist

When releasing a new version, all code blocks flagged with a version number must be updated. Use this list to find them quickly:

```bash
# Find all versioned imports in the current docs
grep -rn "invoice-pro:" docs/docs/ README.md template/
```

---

## Adding a New Code Section

1. Write the code block in the documentation file. Format Typst blocks that start with `#` or `//` with typstyle.
2. Add an entry to the registry table in this file with the correct Code ID, description, and version (if applicable).
3. Add a corresponding entry to the Documentation Test Registry in [TESTING.md](/tests/TESTING.md).
4. Create a test under `tests/docs/` if the code block is non-trivial. If no test is created, mark both entries with ⚠️.
