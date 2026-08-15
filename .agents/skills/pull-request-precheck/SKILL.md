---
name: pull-request-precheck
description: Final validation gatekeeper before opening a pull request or merging into main, executing formatting checks, test suites, docs build, and ZUGFeRD validations.
---

# Pull Request Precheck for invoice-pro

Before opening a pull request or merging changes into `main`, execute the precheck suite to catch any issues that would fail in the GitHub Actions CI pipeline.

---

## Running the Precheck

```bash
# Standard command (in dev shell or with Nix):
./scripts/check-pr

# Or directly with Nix:
nix run .#check-pr
```

---

## Pipeline Steps & Failure Diagnosis

### Step 1: Linter & Formatting (`checks.lint`)

- **Checks**: `typstyle` (Typst formatting), `prettier` (Markdown formatting), `nixpkgs-fmt` (Nix formatting).
- **If it fails**:
  - Run `typstyle -i <file.typ>` on modified Typst files.
  - Run `prettier --write <file.md>` on modified Markdown files.

### Step 2: Test Suite (`tt run`)

- **Checks**: All visual regression, data assertion, and issue regression tests.
- **If it fails**:
  - Check failure output with `tt run`.
  - Refer to the `fix-tests` skill for detailed remediation steps.

### Step 3: Documentation Build (`packages.documentation`)

- **Checks**: Docusaurus compilation and link verification.
- **If it fails**:
  - Check for invalid MDX syntax, broken relative links, or missing sidebar entries in `docs/`.

### Step 4: ZUGFeRD PDF/XML Validations (`validate-all-zugferd`)

- **Checks**: Compiles all integration ZUGFeRD tests to PDF/A-3b, extracts `factur-x.xml`, and validates against EN 16931 Schematron rules via Mustang CLI.
- **If it fails**:
  - Inspect Mustang Schematron error codes (e.g. missing mandatory fields, invalid tax totals).
  - Refer to `tests/TESTING.md` for ZUGFeRD troubleshooting.
