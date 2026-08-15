---
name: workspace-setup
description: Environment setup and developer tool configuration for invoice-pro, supporting Nix environments and non-Nix fallback setups for other agents and environments.
---

# Workspace Setup for invoice-pro

This guide covers setting up the development workspace for `invoice-pro`.

---

## Primary Setup: Nix (Recommended)

The repository provides a complete Nix flake with all dependencies (Typst, Tytanic, Typstyle, Node.js, Yarn, JRE, Mustang CLI, Poppler utils, Prettier).

### Entering the Environment

```bash
nix develop
```

### Running Single Commands via Nix

If not in an interactive shell, prefix commands with:

```bash
nix develop --command <command>
# e.g.:
nix develop --command tt run
```

The Nix shell automatically sets up the local Typst package links so that `@preview/invoice-pro:<version>` and `@preview/loom` are available.

---

## Secondary Setup: Non-Nix Environments (Fallback)

If running in an environment or agent without Nix installed, install the required toolchains manually:

### 1. Required Toolchains

- **Typst CLI**: `>= 0.15.0`
- **Tytanic**: `cargo install --git https://github.com/typst-community/tytanic`
- **Typstyle** (Formatter): `cargo install typstyle`
- **Node.js & Yarn**: `>= 20.0` (for documentation)
- **Prettier**: `npm install -g prettier`
- **Java (JRE)** & **Poppler Utils** (`pdfdetach`): for ZUGFeRD validations
- **Mustang CLI**: Download `mustang-cli.jar` from [Mustangproject](https://www.mustangproject.org/)

### 2. Typst Package Link Workaround

To test package imports like `@preview/invoice-pro:0.4.0`, link the local repository into Typst's local package directory:

```bash
PACKAGE_DIR="$HOME/.local/share/typst/packages/preview/invoice-pro/0.4.0"
mkdir -p "$(dirname "$PACKAGE_DIR")"
ln -s "$(pwd)" "$PACKAGE_DIR"
```

### 3. Running Project Scripts

All scripts under `./scripts/` detect available system binaries:

- `./scripts/validate-zugferd <file.typ>` (uses system `typst`, `pdfdetach`, `mustang-cli`)
- `./scripts/validate-all-zugferd`
- `./scripts/check-version <old-version>`
- `./scripts/check-pr` (runs non-Nix fallback pipeline)
