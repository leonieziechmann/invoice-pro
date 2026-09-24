# Documentation Maintenance Guide

This document tracks all code sections in the documentation and their maintenance status. It serves as the single source of truth for ensuring documentation code examples remain correct and tested.

## Key Rules

1. **Every non-trivial code block** must be listed in the registry below.
2. **Code blocks with version numbers** (e.g., `@preview/invoice-pro:0.4.2`) must be flagged with the version so they can be updated during releases.
3. **When adding a new code section**, register it here and — if possible — create a corresponding test under `tests/docs/`. See [TESTING.md](/tests/TESTING.md) for test setup instructions.
4. **Discrepancy resolution:** When docs and tests diverge, take syntax from the test and structure from the docs. See [TESTING.md](/tests/TESTING.md) for the full rule.

---

## Code Block Registry

All code sections in `docs/docs/`, listed by file. Each entry includes:

- **Code ID** — a short identifier for the code block within the file
- **Description** — what the example demonstrates
- **Version** — if the block contains an import with a version number, it is listed here
- **Test** — the corresponding test directory under `tests/docs/`, or `—` if none exists

### `intro.md`

| Code ID        | Description                                         | Version | Test                  | Notes |
| :------------- | :-------------------------------------------------- | :------ | :-------------------- | :---- |
| `quick-glance` | Full invoice with items, discount, and bank details | `0.4.2` | `docs/intro-minimal/` |       |

### `getting-started.md`

| Code ID         | Description                                      | Version | Test                            | Notes                             |
| :-------------- | :----------------------------------------------- | :------ | :------------------------------ | :-------------------------------- |
| `import`        | Package import statement                         | `0.4.2` | —                               | Trivial one-liner, no test needed |
| `first-invoice` | Minimal invoice with items and tax configuration | `0.4.2` | `docs/getting-started-minimal/` |                                   |

### `contributing.md`

| Code ID      | Description                              | Version | Test | Notes                    |
| :----------- | :--------------------------------------- | :------ | :--- | :----------------------- |
| `dev-shell`  | Nix development shell commands           | —       | —    | Bash commands, not Typst |
| `dev-import` | Import snippet showing package injection | `0.4.2` | —    | Trivial snippet          |
| `pre-commit` | Pre-commit run command                   | —       | —    | Bash command, not Typst  |

### `api-reference/index.md`

| Code ID     | Description                                                       | Version | Test                        | Notes |
| :---------- | :---------------------------------------------------------------- | :------ | :-------------------------- | :---- |
| `blueprint` | Full architectural blueprint with items, payment, bank, signature | `0.4.2` | `docs/api-index-blueprint/` |       |

### `api-reference/invoice.md`

| Code ID            | Description                                                 | Version | Test                        | Notes                             |
| :----------------- | :---------------------------------------------------------- | :------ | :-------------------------- | :-------------------------------- |
| `sender-recipient` | Sender/recipient dictionary structure                       | —       | —                           | Snippet (partial), no test needed |
| `references-dict`  | References as dictionary                                    | —       | —                           | Snippet (partial), no test needed |
| `references-array` | References as array of tuples                               | —       | —                           | Snippet (partial), no test needed |
| `minimal-config`   | Minimal valid configuration with a single item              | `0.4.2` | `docs/api-invoice-minimal/` |                                   |
| `document-type`    | Credit note with `document-type` and `preceding-invoice-nr` | —       | —                           | Snippet (partial), no test needed |

### `api-reference/line-items.md`

No code blocks.

### `api-reference/components.md`

| Code ID                | Description                                           | Version | Test                         | Notes             |
| :--------------------- | :---------------------------------------------------- | :------ | :--------------------------- | :---------------- |
| `payment-goal-default` | Default prompt payment                                | —       | —                            | Trivial one-liner |
| `payment-goal-days`    | Relative deadline (14 days)                           | —       | —                            | Trivial one-liner |
| `payment-goal-date`    | Fixed deadline date                                   | —       | —                            | Trivial one-liner |
| `apply-bulk-tax`       | Apply block wrapping items with shared lower tax rate | `0.4.2` | `docs/api-components-apply/` |                   |

### `api-reference/tax.md`

| Code ID          | Description                         | Version | Test | Notes                                   |
| :--------------- | :---------------------------------- | :------ | :--- | :-------------------------------------- |
| `reverse-charge` | Reverse-charge tax usage on an item | `0.4.2` | —    | Snippet only (no full document context) |
| `custom-tax`     | Custom tax category with `tax.new`  | `0.4.2` | —    | Snippet only (let binding)              |
| `exemption-code` | Exemption with its VATEX code       | `0.4.2` | —    | Compiled by check-docs-examples         |

### `api-reference/theme.md`

| Code ID           | Description                                          | Version | Test                      | Notes |
| :---------------- | :--------------------------------------------------- | :------ | :------------------------ | :---- |
| `din5008-example` | DIN-5008 theme with custom form, font, and hole-mark | `0.4.2` | `docs/api-theme-din5008/` |       |
| `blank-example`   | Blank theme with native Typst page setup             | `0.4.2` | `docs/api-theme-blank/`   |       |
| `prints-example`  | Layout of its own that says it prints the references | `0.4.2` | —                         |       |

### `e-invoicing.md`

| Code ID                 | Description                                              | Version | Test                            | Notes                             |
| :---------------------- | :------------------------------------------------------- | :------ | :------------------------------ | :-------------------------------- |
| `attach`                | How the XML is attached with `pdf.attach`                | —       | —                               | Illustration of the internals     |
| `compile`               | PDF/A-3b compile command                                 | —       | —                               | Bash command, not Typst           |
| `error-output`          | Example of the compiler error listing all problems       | —       | —                               | Compiler output, not Typst        |
| `zugferd-errors-report` | Enabling `zugferd-errors: "report"`                      | —       | —                               | Snippet (partial), no test needed |
| `printed-details`       | References with the seller's VAT ID and date of supply   | `0.4.2` | —                               | Compiled by check-docs-examples   |
| `custom-report`         | Theme `zugferd-report` function for a custom list        | —       | `docs/e-invoicing-report/`      |                                   |
| `party-snippets`        | City, seller identifier, contact, buyer reference, EAS   | —       | —                               | Snippets (partial)                |
| `unit-snippets`         | Unit builder and dictionary units                        | —       | —                               | Snippets (partial)                |
| `credit-note`           | Credit note (document type 381) with a preceding invoice | `0.4.2` | `docs/e-invoicing-credit-note/` |                                   |
| `service-period`        | `service-period` printed by `references.service-time()`  | —       | —                               | Snippet (partial), no test needed |
| `exemption-code`        | Exemption with its VATEX code (BT-121)                   | —       | —                               | Snippet (partial), no test needed |
| `notes`                 | Invoice notes, one with a subject code                   | —       | —                               | Snippet (partial), no test needed |
| `item-data`             | Note, date and country of origin of items                | `0.4.2` | `docs/e-invoicing-item-data/`   |                                   |
| `currency`              | Invoice in US dollars                                    | —       | —                               | Snippet (partial), no test needed |
| `facturx-recipe`        | Optional Mustang post-processing for the XMP metadata    | —       | —                               | Bash commands, not Typst          |
| `complete-example`      | Complete ZUGFeRD-compliant invoice                       | `0.4.2` | `docs/e-invoicing-complete/`    |                                   |

### `api-reference/locale/index.md`

| Code ID            | Description                                         | Version | Test | Notes                           |
| :----------------- | :-------------------------------------------------- | :------ | :--- | :------------------------------ |
| `locale-usage`     | Setting locale in show rule                         | —       | —    | Trivial snippet                 |
| `locale-customize` | Locale customization with `locale.custom` overrides | `0.1.0` | —    | ⚠️ Outdated version. Needs test |
| `currency-format`  | Custom currency formatting override                 | —       | —    | Needs test                      |

### `api-reference/locale/custom.md`

| Code ID       | Description                                 | Version | Test | Notes                             |
| :------------ | :------------------------------------------ | :------ | :--- | :-------------------------------- |
| `pl-language` | Polish language dictionary definition       | `0.4.2` | —    | Part of multi-file locale example |
| `pl-region`   | Polish region builder function              | `0.4.2` | —    | Part of multi-file locale example |
| `pl-factory`  | Building locale with `build-locale` factory | `0.4.2` | —    | Part of multi-file locale example |
| `pl-usage`    | Using the custom locale in a document       | `0.4.2` | —    | Part of multi-file locale example |

### `api-reference/locale/base.md`

| Code ID           | Description                                     | Version | Test | Notes      |
| :---------------- | :---------------------------------------------- | :------ | :--- | :--------- |
| `schema-override` | Schema inspection and partial language override | `0.4.2` | —    | Needs test |

---

## Version Bump Checklist

When releasing a new version, all code blocks flagged with a version number must be updated. Use this list to find them quickly:

```bash
# Find all versioned imports in the current docs
grep -rn "invoice-pro:" docs/docs/
```

---

## Adding a New Code Section

1. Write the code block in the documentation file.
2. Add an entry to the registry table in this file with the correct Code ID, description, and version (if applicable).
3. Add a corresponding entry to the Documentation Test Registry in [TESTING.md](/tests/TESTING.md).
4. Create a test under `tests/docs/` if the code block is non-trivial. If no test is created, mark both entries with ⚠️.
