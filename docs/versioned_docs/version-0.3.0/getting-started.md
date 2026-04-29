---
sidebar_position: 2
---

# Getting Started

Welcome to `invoice-pro`. This guide provides the "Fast Path" to generating your first professional invoice, outlining the installation, a minimal setup, and the core architectural workflow.

## Installation

To include `@preview/invoice-pro` in your Typst project, simply import it from the official package repository.

```typst
// Import the core invoice environment and necessary components
#import "@preview/invoice-pro:0.3.0": *
```

:::info
Always check for the latest package version in the Typst Universe to ensure you have the most recent **Normalized** tax templates and locale dictionaries.
:::

## Your First Invoice

The most efficient workflow for initializing a document is to use a `#show` rule with the `invoice.with(..)` function at the root of your Typst file. This establishes the document layout and allows global configuration to automatically propagate to all underlying elements.

Here is a minimal, copy-paste example to get you started:

```typst
#import "@preview/invoice-pro:0.3.0": *

// 1. Initialize the document using a show rule
#show: invoice.with(
  // Sender and recipient configurations
  sender: (
    name: "Acme Corporation",
    address: "123 Business Rd, Metropolis, NY 10001",
  ),
  recipient: (
    name: "John Doe",
    address: "456 Consumer Way, Gotham, NJ 07001",
  ),

  // Document metadata
  invoice-nr: "INV-2026-001", // Unique document identifier
  date: datetime.today(),     // Sets the invoice date to compilation time

  // Financial configuration
  tax-mode: "exclusive",      // Base prices do not include tax
  tax: 0.19                   // Applies a 19% default tax rate
)

// 2. Define the invoice body
= Services Rendered

// Add individual line items; these automatically inherit root settings
#line-items[
  #item(
    title: "Consultation Fee",
    description: "Initial system architecture review.",
    quantity: 10,
    price: 150.00
  )

  #item(
    title: "Server Migration",
    quantity: 1,
    price: 500.00
  )
]
```

:::tip
If your business falls under a small enterprise exemption scheme (e.g., _Kleinunternehmerregelung_ in Germany), simply set `tax-exempt-small-biz: true` and `tax: auto` in the root `#show` rule. The module will automatically suppress tax rendering and output the correct legal **Grounds** based on your configured `locale`.
:::

## Understanding the Workflow

`invoice-pro` relies on a robust top-down data architecture to ensure consistency and precision across the document.

1. **The Root Context:** The `invoice` function acts as the primary orchestrator. Settings defined here—such as `theme`, `locale`, `tax-mode`, and default `tax` rates—are aggressively **Normalized** to ensure a standard data shape across the entire pipeline.
2. **Cascading Data:** Once initialized, this context begins **Cascading** downward. When you invoke an `#item()` block in the document body, it does not need to redefine the tax rate or currency; it implicitly inherits the active state from the root environment.
3. **Multi-Pass Evaluation:** The underlying engine runs a two-pass calculation step. As components are evaluated, the system uses **Forward/Backward Calculation** to accurately compute line-item totals, aggregate all financial data into respective tax **Grounds**, and build the final balances table dynamically at the bottom of your document.

:::warning
Do not bypass the root `invoice` wrapper when using `invoice-pro` components. Because these components are built on top of the `loom` state engine, attempting to declare an `item` outside of the `invoice` context will result in a missing dependency state. The components will simply not render or execute at all.
:::
