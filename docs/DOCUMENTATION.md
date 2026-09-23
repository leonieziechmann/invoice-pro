# Documentation Maintenance Guide

This document tracks all code sections in the documentation and their maintenance status. It serves as the single source of truth for ensuring documentation code examples remain correct and tested.

## Key Rules

1. **Every non-trivial code block** must be listed in the registry below.
2. **Code blocks with version numbers** (e.g., `@preview/invoice-pro:0.5.0`) must be flagged with the version so they can be updated during releases.
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
| `quick-glance` | Full invoice with items, discount, and bank details | `0.5.0` | `docs/intro-minimal/` |       |

### `getting-started.md`

| Code ID         | Description                                      | Version | Test                            | Notes                             |
| :-------------- | :----------------------------------------------- | :------ | :------------------------------ | :-------------------------------- |
| `import`        | Package import statement                         | `0.5.0` | —                               | Trivial one-liner, no test needed |
| `nix-run`       | Compile with Nix without installation            | —       | —                               | Bash command, not Typst           |
| `first-invoice` | Minimal invoice with items and tax configuration | `0.5.0` | `docs/getting-started-minimal/` |                                   |
| `choose-look`   | Another preset with a brand color                | —       | `docs/getting-started-look/`    |                                   |

### `b2b.md`

| Code ID          | Description                                            | Version | Test                       | Notes |
| :--------------- | :----------------------------------------------------- | :------ | :------------------------- | :---- |
| `national`       | National B2B invoice with register and management keys | `0.5.0` | `docs/b2b-national/`       |       |
| `reverse-charge` | Cross-border B2B invoice with reverse charge           | `0.5.0` | `docs/b2b-reverse-charge/` |       |

### `b2c.md`

| Code ID     | Description                                 | Version | Test                  | Notes |
| :---------- | :------------------------------------------ | :------ | :-------------------- | :---- |
| `national`  | National B2C invoice with gross prices      | `0.5.0` | `docs/b2c-national/`  |       |
| `small-biz` | B2C invoice under the small business scheme | `0.5.0` | `docs/b2c-small-biz/` |       |

### `contributing.md`

| Code ID      | Description                              | Version | Test | Notes                    |
| :----------- | :--------------------------------------- | :------ | :--- | :----------------------- |
| `dev-shell`  | Nix development shell commands           | —       | —    | Bash commands, not Typst |
| `dev-import` | Import snippet showing package injection | `0.5.0` | —    | Trivial snippet          |
| `pre-commit` | Pre-commit run command                   | —       | —    | Bash command, not Typst  |

### `api-reference/index.md`

| Code ID     | Description                                                             | Version | Test                        | Notes |
| :---------- | :---------------------------------------------------------------------- | :------ | :-------------------------- | :---- |
| `blueprint` | Full architectural blueprint with items, payment terms, bank, signature | `0.5.0` | `docs/api-index-blueprint/` |       |

### `api-reference/invoice/index.md`

| Code ID               | Description                                                 | Version | Test                        | Notes                             |
| :-------------------- | :---------------------------------------------------------- | :------ | :-------------------------- | :-------------------------------- |
| `sender-recipient`    | Sender/recipient dictionaries with register keys            | —       | `docs/api-invoice-parties/` | Wrapped in a show rule            |
| `theme`               | Theme parameter with a brand and an explicit layout         | —       | `docs/api-invoice-theme/`   | Wrapped in a show rule            |
| `references-preset`   | References as a preset package                              | —       | —                           | Snippet (partial), no test needed |
| `references-builders` | References as builder functions                             | —       | —                           | Snippet (partial), no test needed |
| `references-array`    | References as array of tuples                               | —       | —                           | Snippet (partial), no test needed |
| `references-dict`     | References as dictionary                                    | —       | —                           | Snippet (partial), no test needed |
| `compile-a3b`         | Compile command with PDF/A-3b                               | —       | —                           | Bash command, not Typst           |
| `zugferd-example`     | Show rule with the `en16931` profile                        | —       | `docs/api-invoice-zugferd/` | Followed by `body()`              |
| `minimal-config`      | Minimal valid configuration with a single item              | `0.5.0` | `docs/api-invoice-minimal/` |                                   |
| `document-type`       | Credit note with `document-type` and `preceding-invoice-nr` | —       | —                           | Snippet (partial), no test needed |

### `api-reference/invoice/validation.md`

| Code ID         | Description                                      | Version | Test                                  | Notes                                               |
| :-------------- | :----------------------------------------------- | :------ | :------------------------------------ | :-------------------------------------------------- |
| `draft`         | Draft with a missing number and address, ZUGFeRD | `0.5.0` | `docs/api-invoice-validation-draft/`  | Renders the draft and the report page               |
| `cli`           | `--input invoice-pro-validation` commands        | —       | —                                     | Bash commands, not Typst                            |
| `strict-output` | Message of the draft example under `strict`      | —       | `docs/api-invoice-validation-strict/` | Asserts the message with `catch` and renders it     |
| `locale-patch`  | Custom inline marker through a locale patch      | —       | `docs/api-invoice-validation-locale/` | The test sets `invoice-nr: none` to show the marker |

### `api-reference/invoice/country.md`

| Code ID          | Description                                        | Version | Test                    | Notes                                                     |
| :--------------- | :------------------------------------------------- | :------ | :---------------------- | :-------------------------------------------------------- |
| `country-usage`  | Country configurations for both parties            | `0.5.0` | `docs/country-example/` | The test adds a theme and asserts the parsed addresses    |
| `post-code-dict` | City and post code as a dictionary                 | —       | `docs/country-custom/`  | Snippet (partial), asserted in the test                   |
| `country-with`   | Custom country name via `.with`                    | —       | —                       | Snippet (let binding), no test needed                     |
| `country-custom` | Countries outside the module with `country.custom` | —       | `docs/country-custom/`  | The test adds an invoice and asserts the parsed addresses |

### `api-reference/invoice/identifiers.md`

| Code ID                | Description                                                                      | Version | Test                             | Notes                             |
| :--------------------- | :------------------------------------------------------------------------------- | :------ | :------------------------------- | :-------------------------------- |
| `where-ids-go`         | Identifiers of the `id` module on the parties                                    | —       | —                                | Snippet (partial), no test needed |
| `printing-identifiers` | Register number as legal registration identifier and printed in the legal footer | `0.5.0` | `docs/api-identifiers-printing/` |                                   |

### `api-reference/invoice/references.md`

| Code ID             | Description                                    | Version | Test | Notes                                     |
| :------------------ | :--------------------------------------------- | :------ | :--- | :---------------------------------------- |
| `import`            | Import of the `references` module              | `0.5.0` | —    | Trivial one-liner                         |
| `preset-b2b`        | `preset-b2b()` and its expansion               | —       | —    | Snippet (partial), no test needed         |
| `preset-b2g`        | `preset-b2g()` and its expansion               | —       | —    | Snippet (partial), no test needed         |
| `preset-project`    | `preset-project()` and its expansion           | —       | —    | Snippet (partial), no test needed         |
| `preset-din-5008`   | `preset-din-5008()` and its expansion          | —       | —    | Snippet (partial), no test needed         |
| `builder-overrides` | Builder functions with custom labels or values | —       | —    | Snippet (partial), no test needed         |
| `usage-preset`      | Show rule with a preset                        | —       | —    | ⚠️ Snippet with `// ...`; not implemented |
| `usage-builders`    | Show rule with builder functions               | —       | —    | ⚠️ Snippet with `// ...`; not implemented |
| `usage-dict`        | Show rule with a dictionary of builders        | —       | —    | ⚠️ Snippet with `// ...`; not implemented |

### `api-reference/line-items/index.md`

| Code ID            | Description                               | Version | Test                                    | Notes                                     |
| :----------------- | :---------------------------------------- | :------ | :-------------------------------------- | :---------------------------------------- |
| `group-subtotal`   | Group without subtotal                    | —       | —                                       | Snippet (partial), no test needed         |
| `group-cascade`    | Group with cascading tax and unit         | —       | —                                       | Snippet (partial), no test needed         |
| `nested-numbering` | Hierarchical position numbering           | —       | —                                       | ⚠️ Needs an invoice; not implemented      |
| `prepayment`       | Prepayments (absolute, dated, percentage) | —       | —                                       | ⚠️ Needs an invoice; not implemented      |
| `bundle-nested`    | Nested bundles with a percentage discount | —       | `docs/api-line-items-bundle-modifiers/` | The test places the block in `line-items` |
| `modifier-tax`     | Shipping pinned to the standard VAT rate  | —       | `docs/api-line-items-bundle-modifiers/` | Same test                                 |

### `api-reference/line-items/unit.md`

| Code ID      | Description                                | Version | Test | Notes                                     |
| :----------- | :----------------------------------------- | :------ | :--- | :---------------------------------------- |
| `unit-usage` | Units from the `unit` module in a document | `0.5.0` | —    | ⚠️ Snippet with `// ...`; not implemented |
| `unit-dict`  | Structure of a resolved unit               | —       | —    | Data structure, not runnable              |

### `api-reference/components.md`

| Code ID                  | Description                                           | Version | Test                           | Notes                                                               |
| :----------------------- | :---------------------------------------------------- | :------ | :----------------------------- | :------------------------------------------------------------------ |
| `payment-terms-default`  | Default prompt payment                                | —       | —                              | Trivial one-liner                                                   |
| `payment-terms-days`     | Relative deadline (14 days)                           | —       | —                              | Trivial one-liner                                                   |
| `payment-terms-date`     | Fixed deadline date                                   | —       | —                              | Trivial one-liner                                                   |
| `payment-terms-discount` | Cash discount (Skonto) in two steps                   | —       | `docs/api-components-payment/` | Asserts the printed sentence                                        |
| `direct-debit`           | SEPA direct debit                                     | —       | `docs/api-components-payment/` | Same test, asserts the printed texts                                |
| `card-payment`           | Payment by credit card                                | —       | `docs/api-components-payment/` | Same test                                                           |
| `paid`                   | Paid invoice in cash                                  | —       | `docs/api-components-payment/` | Same test                                                           |
| `paid-card`              | Paid invoice by card                                  | —       | `docs/api-components-payment/` | Same test                                                           |
| `apply-bulk-tax`         | Apply block wrapping items with shared lower tax rate | `0.5.0` | `docs/api-components-apply/`   | The test places the block in `line-items`                           |
| `info-usage`             | `info` motifs in body text                            | `0.5.0` | `docs/api-components-info/`    | `info.due-date` and `info.iban` currently render empty in body text |
| `info-dynamic`           | `info.dynamic` path queries                           | —       | `docs/api-components-info/`    | Same test as `info-usage`                                           |

### `api-reference/tax.md`

| Code ID          | Description                         | Version | Test | Notes                                   |
| :--------------- | :---------------------------------- | :------ | :--- | :-------------------------------------- |
| `reverse-charge` | Reverse-charge tax usage on an item | `0.5.0` | —    | Snippet only (no full document context) |
| `custom-tax`     | Custom tax category with `tax.new`  | `0.5.0` | —    | Snippet only (let binding)              |
| `exemption-code` | Exemption with its VATEX code       | `0.5.0` | —    | Compiled by check-docs-examples         |

### `api-reference/theme/index.md`

| Code ID       | Description                                       | Version | Test                          | Notes                             |
| :------------ | :------------------------------------------------ | :------ | :---------------------------- | :-------------------------------- |
| `quick-start` | `theme.classic` with a brand, a logo and no marks | `0.5.0` | `docs/api-theme-quick-start/` | Logo fixture `logo.svg`           |
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
| `region`      | `layout: auto` for an Austrian sender                 | `0.5.0` | `docs/api-theme-layouts-region/`      | Asserts `din-5008-b`                         |
| `for-region`  | A region function from a job file                     | —       | `docs/api-theme-layouts-for-region/`  | Asserts the region mapping                   |
| `areas`       | Area patches: logo right, references moved, no header | —       | `docs/api-theme-layouts-areas/`       | Logo fixture `logo.svg`                      |
| `derive`      | A company layout with `theme.layout.derive`           | —       | `docs/api-theme-layouts-derive/`      |                                              |
| `stationery`  | The three stationery modes from one input             | —       | `docs/api-theme-layouts-stationery/`  | Renders the default mode `pdf`; SVG fixtures |
| `proof`       | Envelopes and the print proof                         | —       | `docs/api-theme-layouts-proof/`       | The test switches the proof on by default    |
| `roll`        | An 80 mm thermal-roll receipt                         | `0.5.0` | `docs/api-theme-layouts-roll/`        |                                              |
| `din-listing` | DIN 5008 form A and B as data                         | —       | `docs/api-theme-layouts-din-listing/` | Asserts equality with the shipped layouts    |
| `qr-bill`     | Swiss layout with the QR-bill zone (0.6.x preview)    | —       | `docs/api-theme-layouts-qr-bill/`     | The test switches the zone on by default     |

### `api-reference/theme/parts.md`

| Code ID          | Description                                      | Version | Test                                   | Notes                                           |
| :--------------- | :----------------------------------------------- | :------ | :------------------------------------- | :---------------------------------------------- |
| `contract`       | Replace, wrap and eject parts                    | —       | `docs/api-theme-parts-contract/`       |                                                 |
| `payment-terms`  | A payment-terms part built from its view         | —       | `docs/api-theme-parts-payment-terms/`  |                                                 |
| `footer-content` | Content cells with `info` motifs in the footer   | —       | `docs/api-theme-parts-footer-content/` |                                                 |
| `custom-area`    | A prefixed custom part in a new foreground area  | —       | `docs/api-theme-parts-custom-area/`    |                                                 |
| `themed`         | `themed` scopes for a group and the bank details | —       | `docs/api-theme-parts-themed/`         | The test adds the show rule                     |
| `package-lib`    | A zero-import theme package                      | —       | `docs/api-theme-parts-package/`        | The package is the local file `acme-theme.typ`  |
| `package-usage`  | Using the package with a preset                  | `0.5.0` | `docs/api-theme-parts-package/`        |                                                 |
| `package-ci`     | `theme.resolve` in the package CI                | —       | `docs/api-theme-parts-package/`        |                                                 |
| `resolve`        | `theme.resolve` assertions                       | —       | `docs/api-theme-parts-resolve/`        | The test also renders an invoice with the theme |

### `api-reference/theme/migration.md`

| Code ID  | Description                      | Version | Test                        | Notes                                |
| :------- | :------------------------------- | :------ | :-------------------------- | :----------------------------------- |
| `before` | A 0.5 document                   | —       | —                           | 0.5 code, intentionally not compiled |
| `after`  | The same document in 0.6         | —       | `docs/api-theme-migration/` |                                      |
| `error`  | Message of a 0.5 theme parameter | —       | —                           | Plain text                           |

### `e-invoicing/index.md`

| Code ID            | Description                        | Version | Test                         | Notes                   |
| :----------------- | :--------------------------------- | :------ | :--------------------------- | :---------------------- |
| `compile`          | PDF/A-3b compile command           | —       | —                            | Bash command, not Typst |
| `complete-example` | Complete ZUGFeRD-compliant invoice | `0.5.0` | `docs/e-invoicing-complete/` |                         |

### `e-invoicing/architecture.md`

| Code ID    | Description                                          | Version | Test | Notes                         |
| :--------- | :--------------------------------------------------- | :------ | :--- | :---------------------------- |
| `pipeline` | Diagram of the way from the invoice to the e-invoice | —       | —    | Mermaid diagram, not Typst    |
| `attach`   | How the XML is attached with `pdf.attach`            | —       | —    | Illustration of the internals |

### `e-invoicing/validation.md`

| Code ID                 | Description                                            | Version | Test                       | Notes                             |
| :---------------------- | :----------------------------------------------------- | :------ | :------------------------- | :-------------------------------- |
| `error-output`          | Example of the compiler error listing all problems     | —       | —                          | Compiler output, not Typst        |
| `zugferd-errors-report` | Enabling `zugferd-errors: "report"`                    | —       | —                          | Snippet (partial), no test needed |
| `custom-report`         | A `zugferd-report` part for a custom list              | —       | `docs/e-invoicing-report/` |                                   |
| `printed-details`       | References with the seller's VAT ID and date of supply | `0.5.0` | —                          | Compiled by check-docs-examples   |

### `e-invoicing/limitations.md`

| Code ID          | Description                                           | Version | Test | Notes                    |
| :--------------- | :---------------------------------------------------- | :------ | :--- | :----------------------- |
| `facturx-recipe` | Optional Mustang post-processing for the XMP metadata | —       | —    | Bash commands, not Typst |

### `e-invoicing/invoice-data/parties.md`

| Code ID          | Description                                                                       | Version | Test | Notes              |
| :--------------- | :-------------------------------------------------------------------------------- | :------ | :--- | :----------------- |
| `party-snippets` | City, seller identifier, contact, buyer reference, EAS, tax representative, payee | —       | —    | Snippets (partial) |

### `e-invoicing/invoice-data/line-items.md`

| Code ID         | Description                                                      | Version | Test                          | Notes                             |
| :-------------- | :--------------------------------------------------------------- | :------ | :---------------------------- | :-------------------------------- |
| `unit-snippets` | Unit builder and dictionary units                                | —       | —                             | Snippets (partial)                |
| `money-fine`    | Unit prices rounded to 6 decimals with `locale.custom.normalize` | —       | —                             | Snippet (partial), no test needed |
| `item-data`     | Note, date and country of origin of items                        | `0.5.0` | `docs/e-invoicing-item-data/` |                                   |

### `e-invoicing/invoice-data/taxes.md`

| Code ID          | Description                            | Version | Test | Notes                             |
| :--------------- | :------------------------------------- | :------ | :--- | :-------------------------------- |
| `exemption-code` | Exemption with its VATEX code (BT-121) | —       | —    | Snippet (partial), no test needed |

### `e-invoicing/invoice-data/payment.md`

| Code ID         | Description                                                   | Version | Test                           | Notes              |
| :-------------- | :------------------------------------------------------------ | :------ | :----------------------------- | :----------------- |
| `direct-debit`  | XRechnung collected by SEPA direct debit                      | `0.5.0` | `docs/e-invoicing-sepa-debit/` |                    |
| `paid-snippets` | Paid invoices in cash and by card                             | —       | —                              | Snippets (partial) |
| `cash-discount` | Cash discount of `payment-terms`, and in a textual `due-date` | —       | —                              | Snippets (partial) |

### `e-invoicing/invoice-data/document.md`

| Code ID          | Description                                              | Version | Test                            | Notes                             |
| :--------------- | :------------------------------------------------------- | :------ | :------------------------------ | :-------------------------------- |
| `credit-note`    | Credit note (document type 381) with a preceding invoice | `0.5.0` | `docs/e-invoicing-credit-note/` |                                   |
| `service-period` | `service-period` printed by `references.service-time()`  | —       | —                               | Snippet (partial), no test needed |
| `notes`          | Invoice notes, one with a subject code                   | —       | —                               | Snippet (partial), no test needed |
| `currency`       | Invoice in US dollars                                    | —       | —                               | Snippet (partial), no test needed |

### `e-invoicing/invoice-data/business-terms.md`

No code blocks. The tables are generated by `tools/zugferd/bt_disposition.py --update-docs`.

### `api-reference/locale/index.md`

| Code ID            | Description                                         | Version | Test                                  | Notes                                       |
| :----------------- | :-------------------------------------------------- | :------ | :------------------------------------ | :------------------------------------------ |
| `locale-usage`     | Setting locale in show rule                         | —       | —                                     | Trivial snippet                             |
| `locale-customize` | Locale customization with `locale.custom` overrides | `0.5.0` | `docs/api-locale-customize/`          | Two pages, to show the page label           |
| `currency-format`  | Custom currency formatting override                 | —       | `docs/api-locale-currency/`           |                                             |
| `validation-texts` | Custom validation marker through a locale patch     | —       | `docs/api-invoice-validation-locale/` | Same code as `validation.md` `locale-patch` |

### `api-reference/locale/custom.md`

| Code ID       | Description                                 | Version | Test                         | Notes                          |
| :------------ | :------------------------------------------ | :------ | :--------------------------- | :----------------------------- |
| `pl-language` | Polish language dictionary definition       | `0.5.0` | `docs/api-locale-custom-pl/` | File `lang/pl.typ` of the test |
| `pl-region`   | Polish region builder function              | `0.5.0` | `docs/api-locale-custom-pl/` | File `region/pl.typ`           |
| `pl-factory`  | Building locale with `build-locale` factory | `0.5.0` | `docs/api-locale-custom-pl/` | File `lib.typ`                 |
| `pl-usage`    | Using the custom locale in a document       | `0.5.0` | `docs/api-locale-custom-pl/` | `test.typ`                     |

### `api-reference/locale/base.md`

| Code ID           | Description                                     | Version | Test                             | Notes |
| :---------------- | :---------------------------------------------- | :------ | :------------------------------- | :---- |
| `schema-override` | Schema inspection and partial language override | `0.5.0` | `docs/api-locale-base-override/` |       |

### `README.md`

| Code ID       | Description                      | Version | Test                           | Notes                   |
| :------------ | :------------------------------- | :------ | :----------------------------- | :---------------------- |
| `install`     | Package import statement         | `0.5.0` | —                              | Trivial one-liner       |
| `basic-usage` | Full invoice                     | `0.5.0` | `docs/readme-getting-started/` |                         |
| `theming`     | A preset with a brand and a logo | —       | `docs/readme-theming/`         | Logo fixture `logo.svg` |
| `nix-run`     | Compile with Nix                 | —       | —                              | Bash command, not Typst |
| `dev-shell`   | Nix development shell            | —       | —                              | Bash command, not Typst |
| `dev-import`  | Import in the development shell  | `0.5.0` | —                              | Trivial one-liner       |
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
