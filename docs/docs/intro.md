---
slug: /
sidebar_position: 1
---

# Introduction

Welcome to the official documentation for `invoice-pro`, an open-source, automated invoicing template designed for Typst. Our goal is to provide a DRY (Don't Repeat Yourself) and declarative API that makes generating compliant invoices straightforward and reliable. Meaning we work hard on making the template derive as much data as possible from your inputs and focus strong on sane defaults and ease of use.

The target group for this template are small businesses in the EU/Schengen Area that want to create high quality B2B and B2C invoices.

## The Engine and Paradigm

At its core, `invoice-pro` relies on an innovative block-based API. This architecture completely decouples your data model from the visual representation. The template not only calculates how it should be displayed but also embeds the data into the document.

The system is focused around ease of use and quality of life. Trying to provide an API that is as intuitive and able to reflect your invoicing needs as possible. Such features include Forward/Backward Calculation, Localization, Smart Item Bundles and e-invoicing. For the future a powerful and extendible theming engine is also planned.

Additionally, the engine handles different `tax-mode` configurations natively. By easily switching between net and gross calculations, `invoice-pro` effortlessly supports both B2B and B2C invoice workflows.

## Quick Glance

The power of `invoice-pro` lies in its conciseness. Below is a minimal example of a consulting invoice to demonstrate the declarative nature of the API:

```typst
#import "@preview/invoice-pro:0.3.2": *

#show: invoice.with(
  // Set the locale for language, formatting, and legal behaviors
  locale: locale.en-de,
  sender: (
    name: "Consulting Group LLC",
    address: "Consulting Street 1",
    city: "Berlin"
  ),
  recipient: (
    name: "Acme Corp",
    address: "Acme Street 1",
    city: "Munich"
  ),
  invoice-nr: "INV-2026-001",
)

// A strictly scoped block where children inherit parameters automatically
#line-items[
  #item([Strategic IT Consulting], quantity: 10, unit: unit.h, price: 150.00)
  #item([Server Infrastructure Audit], price: 1200.00)
  #item([Cloud Migration Support], quantity: 5, unit: unit.h, price: 120.00)

  // Modifiers automatically apply to the context they are placed in
  #discount([Long-term Client Discount], amount: 10%)
]

// Automated bank details with QoL payment features
#bank-details(
  bank: "Example Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
```

## Key Capabilities

- **Locale:** An advanced and extensible locale system that contains not just language translations, but also regional formatting and legal information/behavior.
- **Payment Automation:** Quality-of-life features like automatic EPC-QR-Code (GiroCode) generation make it easier for clients to pay instantly via mobile banking applications.
- **E-Invoicing:** Experimental support for standard e-invoicing formats (such as ZUGFeRD / Factur-X), allowing digital readability alongside human-readable invoices.
- **Theming API (Planned):** A powerful and extendible theming engine designed to allow multiple distinct visual designs out of the box.

## Compliance and Ecosystem

Generating compliant invoices requires handling specific tax logic and regional rules. `invoice-pro` natively supports the EU VAT system and works seamlessly for countries utilizing similar tax models, such as Switzerland and Norway.

The template helps you establish the correct **Grounds** for tax justifications easily. Because our data logic is decoupled from the layout layer, the visual layout can be entirely swapped out without altering your business data. This separation of concerns allows us to offer experimental support for **EN 16931** compliant e-invoicing standards (such as ZUGFeRD / Factur-X). See the [E-Invoicing](./e-invoicing.md) guide for more details.

:::info
The visual layout (such as the German **DIN 5008** standard) is merely a presentation layer. You can swap themes at any time, and your underlying data structure remains perfectly intact.
:::

## Path Forward

:::tip
To ensure your Typst environment is properly configured for automated rendering and PDF generation, we highly recommend starting with the [Getting Started](./getting-started.md) guide.
:::

Once your environment is set up and you understand the basic workflow, you can dive into the specific modules and functions in our detailed [API Reference](./api-reference/index.md).
