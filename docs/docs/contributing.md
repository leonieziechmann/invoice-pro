---
sidebar_position: 11
---

# Development & Contributing

## 🏳️‍⚧️ Inclusive Space 🏳️‍🌈

:::info
`invoice-pro` is committed to fostering an inclusive, welcoming, and safe environment for all contributors. We explicitly affirm our support for transgender rights, visibility, and the broader LGBTQ+ community.

This project enforces a **zero-tolerance policy** for hate speech, discrimination, harassment, or exclusionary behavior of any kind. We believe that technical excellence requires a safe and collaborative community. If you cannot respect these boundaries and treat all peers with dignity, your contributions and presence in this project will not be accepted.
:::

This document outlines the strict guidelines and workflows required for contributing to `invoice-pro`. To minimize maintenance overhead and ensure maximum performance, all development must adhere to the following architectural and workflow principles.

## Development Environment

This project uses **Nix** to provide a reproducible, sandboxed development environment. You do not need to install Typst, linters, or formatters globally—the flake provides everything required, including `tytanic` for testing.

:::warning
Nix is the **only** supported environment for development. All formatting, linting, and environment configurations are strictly managed through the Nix flake. If you choose to develop outside of this environment or submit code that fails within it, support will not be provided.
:::

### Quick Start

1. **Enter the environment:**

```bash
nix develo
# or if you use direnv:
direnv allow
```

This activates a shell containing a custom-wrapped `typst` binary, `typstyle`, `prettier`, `nixpkgs-fmt`, `nodejs`, `yarn`, and `tytanic`.

2. **Automatic Package Injection:**
   The Nix environment automatically wraps the `typst` binary to point `TYPST_PACKAGE_PATH` directly to the Nix store. Your local code and its dependencies (like `loom`) are instantly available as system packages. The shell hook will confirm the available versions upon entry:

```typst
// Import the dynamically linked development version directly
#import "@preview/invoice-pro:0.3.0": *

// Initialize the root environment for testing
#show: invoice.with(..)
```

3. **Quality Control (Pre-commit):**
   Git hooks are automatically configured to run before every commit. Formatting (`typstyle`, `prettier`, `nixpkgs-fmt`) and linting rules defined in the flake must be followed.

```bash
pre-commit run --all-files
```

## Contribution Guidelines

To keep the maintenance burden low, please adhere to the following workflow when proposing changes.

:::note
**Prefer Issues Over Pull Requests:**
Detailed issues are strongly preferred over unexpected pull requests. Often, it is faster and more efficient for the maintainer to implement a feature directly than to perform a comprehensive code review on a PR.

If you intend to submit a PR, you **must** create an issue first. This allows us to verify if the functionality already exists, evaluate the proposed API, and assess its impact on overall usability and rendering speed.
:::

### Scope and Compatibility

The `invoice-pro` template is strictly designed for **EU countries** and regions with highly compatible tax systems (e.g., standard VAT, reverse-charge mechanisms, and standard legal **Grounds**). Features catering to fundamentally different tax architectures will not be accepted.

### Dependency Management

We maintain a strict "minimal dependencies" policy to ensure fast compilation times and long-term stability.

:::tip
Use as few external packages as possible. While delegating complex generation tasks (such as EPC-QR codes) to external libraries is acceptable, standard utility functions must be copied or rewritten directly within the `invoice-pro` codebase. If a third-party package is absolutely necessary and multiple options exist, you must profile them and select the fastest one available.
:::

## Roadmap

The following milestones are planned for future releases of the core engine:

- [x] (v0.2.0) **Refactored API:** Moving away from global states to a more robust, scoped API for better stability and flexibility.
- [x] (WIP) **Internationalization (i18n):** Built-in support for English and other locales (currently generates German invoices by default).
- [ ] **Theming Engine:** Allow easy customization of accent colors and fonts to match corporate identities.
- [ ] **Data Loading:** Helper functions to load invoice items directly from JSON, CSV, or YAML data sources.
- [ ] **ZUGFeRD Support:** (Long-term goal) Embedding XML data for fully compliant, **Normalized** e-invoicing based on standards like **UNTDID 5305**.

## Existing Dependencies

The current architecture relies on the following optimized packages:

- `letter-pro` for the DIN layout.
- `sepay` for EPC-QR-Code generation.
- `ibanator` for IBAN formatting.
- `loom` for reactive document rendering.

:::info
**Acknowledgements:**
Special thanks to [classy-german-invoice](https://github.com/erictapen/typst-invoice) by Kerstin Humm, which served as architectural inspiration and provided the foundational logic for the EPC-QR-Code implementation.
:::

## License

MIT
