---
name: run-tests
description: Guide to executing the various test suites in invoice-pro (Tytanic, Mustang ZUGFeRD, Documentation build) and understanding when each test suite applies.
---

# Running Tests in invoice-pro

This guide explains how to run each test suite in the repository and when each is applicable.

## Test Suites Overview & Applicability Matrix

| Suite                  | Runner / Command                                              | Applicable When                                                                              | Scope                                                        |
| :--------------------- | :------------------------------------------------------------ | :------------------------------------------------------------------------------------------- | :----------------------------------------------------------- |
| **Tytanic Suite**      | `tt run [filter]`                                             | Modifying layout, styling, themes, calculations, issue fixes, or documentation test examples | Visual regression & `data-test` assertions across `tests/**` |
| **ZUGFeRD Validation** | `./scripts/validate-all-zugferd` or `validate-zugferd <path>` | Modifying XML generation (`src/zugferd/`), invoice schema, metadata, VAT/tax rules           | PDF/A-3b compile, XML extraction, Mustang EN16931 validation |
| **Docs Build Check**   | `nix build .#documentation` or `yarn --cwd docs build`        | Modifying documentation (`docs/**`), doc test registry, or package docs                      | Docusaurus production build & broken link check              |
| **PR Precheck**        | `./scripts/check-pr` or `check-pr`                            | Before committing/opening a PR or merging to `main`                                          | Full 4-step pipeline (Linter + Tytanic + Docs + ZUGFeRD)     |

---

## 1. Tytanic Tests

Runs visual regression and calculation tests.

```bash
# Run all tests
tt run

# Run a specific category
tt run "line-items/"
tt run "issues/"
tt run "integration/"
tt run "docs/"

# Run a specific test case
tt run "line-items/totals"
```

_Outside Nix devShell:_ `nix develop .#test --command tt run [filter]`

---

## 2. ZUGFeRD / Factur-X Validation (Mustang CLI)

Validates EN 16931 compliance and XML schema using Mustang CLI.

```bash
# Run all ZUGFeRD test suites & template validation
./scripts/validate-all-zugferd

# Run validation on a single document
./scripts/validate-zugferd "tests/integration/zugferd-basic/test.typ"

# Output compiled PDF to a specific file
./scripts/validate-zugferd "template/invoice.typ" "output/invoice.pdf"
```

_Using Nix run:_ `nix run .#validate-all-zugferd` or `nix run .#validate-zugferd -- "<path>"`

---

## 3. Documentation Build Check

Verifies that documentation compiles cleanly without broken links or syntax errors.

```bash
# With Nix
nix build .#documentation --print-build-logs

# Without Nix (Node.js/Yarn)
(cd docs && yarn build)
```

---

## 4. Comprehensive Precheck

Run all suites in sequence:

```bash
./scripts/check-pr
# or
nix run .#check-pr
```
