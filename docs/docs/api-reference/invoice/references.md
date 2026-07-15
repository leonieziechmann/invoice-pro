---
sidebar_position: 2
---

# Dynamic Reference Signs

The `references` module provides a set of helper functions that automatically fetch, format, and translate document metadata for display in the invoice's reference/header block. This offers ultimate control over which fields are displayed, their layout order, and custom label or value overrides.

## Importing the Module

The `references` module is exported directly from the package root:

```typst
#import "@preview/invoice-pro:0.4.0": invoice, references
```

---

## Available Reference Signs

The module provides the following built-in reference signs:

### `references.tax-nr`

Resolves to the sender's tax number (Steuernummer).

- **Default Label**: Translates to `Steuernummer` (German), `Tax ID` (English), etc.
- **Default Value**: Fetches from `sender.tax-nr` (or the top-level `tax-nr`).

### `references.vat-id`

Resolves to the sender's VAT identifier (USt-IdNr.).

- **Default Label**: Translates to `USt-IdNr.` (German), `VAT ID` (English), etc.
- **Default Value**: Fetches from `sender.vat-id`.

### `references.invoice-nr`

Resolves to the invoice number.

- **Default Label**: Translates to `Rechnungsnummer` (German), `Invoice Number` (English), etc.
- **Default Value**: Fetches from the top-level `invoice-nr` parameter.

### `references.invoice-date`

Resolves to the invoice date, formatted according to the current locale.

- **Default Label**: Translates to `Rechnungsdatum` (German), `Invoice Date` (English), etc.
- **Default Value**: Fetches from the top-level `date` parameter (defaults to today).

### `references.service-time`

Resolves to the time frame/period during which the services or items were provided (Leistungszeitraum).

- **Default Label**: Translates to `Leistungszeitraum` (German), `Period of Service` (English), etc.
- **Default Value**: Automatically scans all items in the invoice and calculates the minimum and maximum dates.
  - If a single date is found, it renders as a singular date.
  - If a date range is found, it renders as a range (e.g., `15.07.2026 – 20.07.2026`).
  - If no items define a date, it falls back to the invoice date.

---

## Customizing Labels & Values

All reference builders accept optional `label` and `value` arguments to override their default behavior:

```typst
references.tax-nr(label: "Custom Tax Label", value: "TAX-123456")
```

If set to `auto` (the default), the values and labels are automatically retrieved and localized.

---

## Usage Styles

You can specify dynamic reference signs using two collection styles:

### As an Array (Preserves Visual Order)

Use an array when the order of references is important. Array elements can be either dynamic reference signs or custom static tuples `(label, value)`.

```typst
#show: invoice.with(
  references: (
    references.invoice-date,
    ("Your Order", "PO-9912"), // Static tuple
    references.vat-id,
    references.tax-nr,
    references.service-time,
  ),
  // ...
)
```

### As a Dictionary (Key-Value Overrides)

Use a dictionary when you want to map custom labels to dynamic references. When a dynamic reference is used as a value inside a dictionary, its own automatic label is discarded, and the dictionary key is used instead.

```typst
#show: invoice.with(
  references: (
    "My custom VAT Label": references.vat-id,
    "Our Reference": "PO-1234",
  ),
  // ...
)
```
