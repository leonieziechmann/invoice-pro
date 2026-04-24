---
sidebar_position: 10
---

# API Reference

Welcome to the **invoice-pro** API Reference. We have structured this section to provide a comprehensive, methodical breakdown of all modules, components, and functions available within the package. Whether you are establishing a basic layout or configuring a complex, legally compliant document, these pages define the architectural primitives of our system.

:::info
The `invoice-pro` package relies on an underlying `loom` state engine. All structural components must be positioned **after** the initial document show rule to properly resolve global configurations.
:::

## Documentation Directory

The API reference is divided into specialized modules, reflecting the technical anatomy of an invoice document.

| Module                                     | Description                                                                                                                                                                                                                |
| :----------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[Invoice](api-reference/invoice)**       | The root document configuration. Details global parameters (e.g., sender, recipient) and initializes the underlying layout engine.                                                                                         |
| **[Line Items](api-reference/line-items)** | The core billing mechanics. Explains how to construct services (`item`), group them (`bundle`), and apply adjustments (`modifier`). This section is critical for understanding automatic **Forward/Backward Calculation**. |
| **[Components](api-reference/components)** | Standalone visual entities. Includes technical specifications for rendering `bank-details`, establishing a `payment-goal`, adding a `signature`, and leveraging the `apply` scoping mechanism.                             |
| **[Tax](api-reference/tax)**               | Standardized tax resolution. Outlines available tax categories compliant with **UNTDID 5305** and **EU Directives**, detailing how to implement specialized margin schemes and legal exemptions.                           |
| **[Locales](api-reference/locale)**        | Language and regional localization. Covers translation overrides, native currency formatting, and regional default overrides.                                                                                              |
| **[Themes](api-reference/theme)**          | Visual layout configurations. Details how the theming engine receives and positions the final structured data on the page.                                                                                                 |

## Core Architectural Concepts

Before engaging with specific module APIs, developers and contributors must understand the fundamental data flows of the engine:

### 1. Cascading Parameters

Properties such as `tax` or `input-gross` are strongly **Cascading**. If defined at a higher context—like the `line-items` wrapper or a `bundle`—all nested descendant elements automatically inherit these properties unless explicitly overridden at the item level.

### 2. Forward/Backward Calculation

The engine guarantees mathematical integrity across all tax brackets. Depending on the active `tax-mode` (`inclusive` or `exclusive`), providing a raw unit price triggers strict **Forward/Backward Calculation** to derive the mathematically sound net and gross totals automatically.

### 3. Normalized Data & Theming

When the engine evaluates your item blocks and global configurations, it compiles them into strictly **Normalized** data objects. The selected visual theme then consumes these standardized objects to compute their precise physical coordinates on the page.

:::warning
Bypassing the API to directly mutate the internal state or the **Normalized** data pipeline is unsupported and will likely introduce breaking changes to the rendering layout.
:::

:::danger
When utilizing the Tax module to declare 0% rates or specific exemptions (e.g., Reverse Charge, Intra-Community Supply), failing to provide the explicit legal **Grounds** parameter will frequently result in a legally invalid document under standard **EU Directives**. Always verify jurisdictional requirements.
:::

## Architectural Blueprint

Below is a foundational structural blueprint illustrating how the modules interact within a standard implementation context.

```typst
// Always import the required functions and modules
#import "@preview/invoice-pro:0.3.0": *

// 1. Invoice Module: Establish the document root and global context
#show: invoice.with(
  sender: (name: "Acme Corp"),
  recipient: (name: "Jane Doe"),
  tax-nr: "DE123456789", // Legally required identifier
  invoice-nr: "INV-2026-001"
)

// 2. Line Items Module: Define the billable content
#line-items[
  #item(
    name: "System Architecture Consulting",
    quantity: 10,
    unit: "h",
    price: 150.00 // Unit price subject to Forward/Backward Calculation
  )
]

// 3. Components Module: Append standalone visual metadata
#payment-goal(days: 14)
#bank-details(iban: "DE12 3456 7890 1234 5678 90")
#signature()
```

:::tip
For a structured learning path, we recommend verifying your understanding of the [Invoice API](./invoice) first, followed by the deep dive into the [Line Items API](./line-items). These two modules cover 90% of standard implementation workflows.
:::
