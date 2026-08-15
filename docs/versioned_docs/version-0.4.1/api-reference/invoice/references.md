---
sidebar_position: 2
---

# Dynamic Reference Signs

The `references` module provides a rich set of helper functions and preset packages that automatically fetch, format, and translate document metadata for display in the invoice's reference / Leitzeichen block.

This offers fine-grained control over which fields are displayed, their layout order, custom label or value overrides, and automatic omission of unpopulated fields.

## Importing the Module

The `references` module is exported directly from the package root:

```typst
#import "@preview/invoice-pro:0.4.1": invoice, references
```

---

## Preset Packages

Preset packages bundle the most common reference combinations for specific business workflows. Any reference field that resolves to `none` is **automatically omitted**, so you can use presets safely without worrying about empty fields appearing on the invoice.

### `references.preset-b2b`

The standard reference configuration for business-to-business invoicing.

```typst
references: references.preset-b2b()
// Evaluates to: [invoice-nr, customer-nr, order-nr, invoice-date, service-time, due-date]
```

### `references.preset-b2g`

Optimized for public administration and government procurement (B2G / XRechnung / Peppol).

```typst
references: references.preset-b2g()
// Evaluates to: [invoice-nr, buyer-reference, order-nr, invoice-date, service-time, due-date]
```

### `references.preset-project`

Tailored for agencies, freelancers, and service contractors billing against specific projects.

```typst
references: references.preset-project()
// Evaluates to: [invoice-nr, customer-nr, project, invoice-date, service-time, due-date]
```

### `references.preset-din-5008`

Follows the classical German DIN 5008 business letter Leitbereich structure (_"Ihre Zeichen / Ihre Nachricht vom / Unsere Zeichen / Tag"_).

```typst
references: references.preset-din-5008()
// Evaluates to: [order-nr, order-date, contact-person, invoice-date]
```

---

## Available Reference Signs

All reference builders accept optional `label` and `value` parameters (e.g. `references.order-nr(label: "PO #", value: "PO-123")`). If left as `auto`, both the label and value are automatically retrieved, formatted, and localized based on the document context and active locale.

### Document & Core

| Function                      | Default Source / Logic                                  | Description                                                                                            |
| :---------------------------- | :------------------------------------------------------ | :----------------------------------------------------------------------------------------------------- |
| **`references.invoice-nr`**   | `ctx.invoice-nr`                                        | Invoice identifier / number.                                                                           |
| **`references.invoice-date`** | `ctx.invoice-date` (`date`)                             | Invoice issue date, formatted according to locale.                                                     |
| **`references.due-date`**     | `ctx.due-date` or derived from `#payment-goal()`        | Payment deadline date.                                                                                 |
| **`references.service-time`** | Computed min & max dates across all `item.date` entries | Period or date of service delivery. Falls back to invoice date if items don't define individual dates. |

### Customer & Recipient

| Function                          | Default Source / Logic                                        | Description                                                              |
| :-------------------------------- | :------------------------------------------------------------ | :----------------------------------------------------------------------- |
| **`references.customer-nr`**      | `ctx.customer-nr`, `recipient.customer-nr`, or `recipient.id` | Customer account or client identifier.                                   |
| **`references.buyer-reference`**  | `recipient.buyer-reference` or `recipient.leitweg-id`         | Buyer reference or Leitweg-ID (EN 16931 BT-10).                          |
| **`references.recipient-vat-id`** | `recipient.vat-id`                                            | Recipient's VAT identification number (essential for EU Reverse Charge). |
| **`references.recipient-tax-nr`** | `recipient.tax-nr`                                            | Recipient's national tax number.                                         |

### Orders, Projects & Procurement

| Function                              | Default Source / Logic                              | Description                                                                  |
| :------------------------------------ | :-------------------------------------------------- | :--------------------------------------------------------------------------- |
| **`references.order-nr`**             | `ctx.order-nr`, `recipient.order-nr`, or `po-nr`    | Customer purchase order / PO number (BT-13).                                 |
| **`references.order-date`**           | `ctx.order-date` or `recipient.order-date`          | Date the order was placed.                                                   |
| **`references.project`**              | `ctx.project` or `ctx.project-nr`                   | Project name or tracking reference (BT-11).                                  |
| **`references.contract-nr`**          | `ctx.contract-nr`                                   | Framework agreement or contract number (BT-12).                              |
| **`references.quote-nr`**             | `ctx.quote-nr` or `ctx.offer-nr`                    | Preceding quotation or estimate reference number.                            |
| **`references.delivery-note-nr`**     | `ctx.delivery-note-nr`                              | Despatch advice / delivery note number (BT-16).                              |
| **`references.preceding-invoice-nr`** | `ctx.preceding-invoice-nr` or `original-invoice-nr` | Preceding invoice reference for credit notes or correction invoices (BT-25). |

### Sender, Contacts & Banking

| Function                           | Default Source / Logic                                   | Description                                                  |
| :--------------------------------- | :------------------------------------------------------- | :----------------------------------------------------------- |
| **`references.tax-nr`**            | `sender.tax-nr`                                          | Sender's tax identifier.                                     |
| **`references.vat-id`**            | `sender.vat-id`                                          | Sender's VAT ID.                                             |
| **`references.payment-reference`** | `ctx.payment-reference` or `ctx.invoice-nr`              | Structured bank transfer purpose (Verwendungszweck).         |
| **`references.contact-person`**    | `sender.contact.name`, `sender.contact-name`, or `clerk` | Name of the clerk or account manager who issued the invoice. |
| **`references.contact-phone`**     | `sender.contact.phone` or `sender.phone`                 | Direct telephone number of the contact person.               |
| **`references.contact-email`**     | `sender.contact.email` or `sender.email`                 | Email address of the contact person.                         |

---

## Customizing Labels & Values

All reference builder functions can be customized with explicit overrides:

```typst
// Custom label with automatic value resolution:
references.customer-nr(label: "Client ID")

// Custom value with automatic label translation:
references.order-nr(value: "PO-2026-99")

// Complete override:
references.due-date(label: "Pay Before", value: "31.12.2026")
```

---

## Usage Styles

You can pass references using three flexible patterns:

### 1. Using a Preset Pack

```typst
#show: invoice.with(
  references: references.preset-b2b(),
  customer-nr: "KD-12345",
  order-nr: "PO-9988",
  // ...
)
```

### 2. Ordered Array (Custom Selection & Order)

Array elements can be builder functions, preset packs, or static `(label, value)` tuples. Elements with `none` values are automatically filtered out.

```typst
#show: invoice.with(
  references: (
    references.invoice-nr(),
    references.customer-nr(),
    references.order-nr(),
    ("Custom Note", "Approved by Management"),
    references.due-date(),
  ),
  // ...
)
```

### 3. Key-Value Dictionary

```typst
#show: invoice.with(
  references: (
    "Our Reference": references.invoice-nr,
    "Your Account": references.customer-nr,
    "Direct Dial": references.contact-phone,
  ),
  // ...
)
```
