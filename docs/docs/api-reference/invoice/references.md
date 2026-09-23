---
sidebar_position: 2
---

# Dynamic Reference Signs

The `references` module provides a rich set of helper functions and preset packages that automatically fetch, format, and translate document metadata for display in the invoice's reference / Leitzeichen block.

This offers fine-grained control over which fields are displayed, their layout order, custom label or value overrides, and automatic omission of unpopulated fields.

## Importing the Module

The `references` module is exported directly from the package root:

```typst
#import "@preview/invoice-pro:0.4.2": invoice, references
```

---

## Preset Packages

Preset packages bundle the most common reference combinations for specific business workflows. Any reference field that resolves to `none` is **automatically omitted**, so you can use presets safely without worrying about empty fields appearing on the invoice.

Every preset prints what the law requires on an invoice besides the parties and the items (§ 14 Abs. 4 UStG in Germany, Art. 226 of the VAT Directive): the date of the supply (`service-time`), the seller's tax number and VAT ID and the buyer's VAT ID (`seller-tax-nr`, `seller-vat-id`, `buyer-vat-id`, which on a self-billed invoice are the recipient's and the sender's) and the `payee`, each if it is given. Earlier versions printed the sender's tax identifiers on a self-billed invoice, and `preset-din-5008` none of them.

### `references.preset-b2b`

The standard reference configuration for business-to-business invoicing.

```typst
references: references.preset-b2b()
// Evaluates to: [invoice-nr, customer-nr, order-nr, invoice-date, service-time, due-date, seller-tax-nr, seller-vat-id, buyer-vat-id, payee]
```

### `references.preset-b2g`

Optimized for public administration and government procurement (B2G / XRechnung / Peppol).

```typst
references: references.preset-b2g()
// Evaluates to: [invoice-nr, buyer-reference, order-nr, invoice-date, service-time, due-date, seller-tax-nr, seller-vat-id, buyer-vat-id, payee]
```

### `references.preset-project`

Tailored for agencies, freelancers, and service contractors billing against specific projects.

```typst
references: references.preset-project()
// Evaluates to: [invoice-nr, customer-nr, project, invoice-date, service-time, due-date, seller-tax-nr, seller-vat-id, buyer-vat-id, payee]
```

### `references.preset-din-5008`

Follows the classical German DIN 5008 business letter Leitbereich structure (_"Ihre Zeichen / Ihre Nachricht vom / Unsere Zeichen / Tag"_), followed by what the law requires on an invoice.

```typst
references: references.preset-din-5008()
// Evaluates to: [order-nr, order-date, contact-person, invoice-date, service-time, seller-tax-nr, seller-vat-id, buyer-vat-id, payee]
```

---

## Available Reference Signs

All reference builders accept optional `label` and `value` parameters (e.g. `references.order-nr(label: "PO #", value: "PO-123")`). If left as `auto`, both the label and value are automatically retrieved, formatted, and localized based on the document context and active locale.

### Document & Core

| Function                      | Default Source / Logic                                                           | Description                                                                                                                                                                                                                                                                                                                                                                               |
| :---------------------------- | :------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`references.invoice-nr`**   | `ctx.invoice-nr`                                                                 | Invoice identifier / number.                                                                                                                                                                                                                                                                                                                                                              |
| **`references.invoice-date`** | `ctx.invoice-date` (`date`)                                                      | Invoice issue date, formatted according to locale.                                                                                                                                                                                                                                                                                                                                        |
| **`references.due-date`**     | `ctx.due-date` or derived from `#payment-goal()`                                 | Payment deadline date.                                                                                                                                                                                                                                                                                                                                                                    |
| **`references.service-time`** | The invoice's `service-period`, else the earliest and latest `date` of the items | Period or date of service delivery, as the e-invoice states it (BT-72 / BG-14). Items without a date do not count; the invoice date is used if no item has a date. A `value` given as a `datetime` or a period `(start, end)` is printed in the date format of the locale. The e-invoice compares the printed service period with the one it states (`IP-PERIOD-01`), whatever its label. |

### Customer & Recipient

| Function                          | Default Source / Logic                                        | Description                                                                                                      |
| :-------------------------------- | :------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------- |
| **`references.customer-nr`**      | `ctx.customer-nr`, `recipient.customer-nr`, or `recipient.id` | Customer account or client identifier. An identifier of the `id` module (e.g. `id: id.gln(..)`) prints its `id`. |
| **`references.buyer-reference`**  | `recipient.buyer-reference` or `recipient.leitweg-id`         | Buyer reference or Leitweg-ID (EN 16931 BT-10).                                                                  |
| **`references.recipient-vat-id`** | `recipient.vat-id`                                            | Recipient's VAT identification number (essential for EU Reverse Charge).                                         |
| **`references.recipient-tax-nr`** | `recipient.tax-nr`                                            | Recipient's national tax number.                                                                                 |

### Orders, Projects & Procurement

| Function                                | Default Source / Logic                                 | Description                                                                  |
| :-------------------------------------- | :----------------------------------------------------- | :--------------------------------------------------------------------------- |
| **`references.order-nr`**               | `ctx.order-nr`, `recipient.order-nr`, or `po-nr`       | Customer purchase order / PO number (BT-13).                                 |
| **`references.order-date`**             | `ctx.order-date` or `recipient.order-date`             | Date the order was placed.                                                   |
| **`references.project`**                | `ctx.project` or `ctx.project-nr`                      | Project name or tracking reference (BT-11).                                  |
| **`references.contract-nr`**            | `ctx.contract-nr` or `recipient.contract-nr`           | Framework agreement or contract number (BT-12).                              |
| **`references.quote-nr`**               | `ctx.quote-nr` or `ctx.offer-nr`                       | Preceding quotation or estimate reference number.                            |
| **`references.delivery-note-nr`**       | `ctx.delivery-note-nr` or `recipient.delivery-note-nr` | Despatch advice / delivery note number (BT-16).                              |
| **`references.delivery-address`**       | `ctx.delivery-address` or `recipient.delivery-address` | Separate delivery / shipping destination address (BG-13 / BT-56-79).         |
| **`references.preceding-invoice-nr`**   | `ctx.preceding-invoice-nr` or `original-invoice-nr`    | Preceding invoice reference for credit notes or correction invoices (BT-25). |
| **`references.preceding-invoice-date`** | `ctx.preceding-invoice-date`                           | Date of the preceding invoice, formatted according to locale (BT-26).        |

### Sender, Contacts & Banking

| Function                           | Default Source / Logic                                                            | Description                                                                                                                                                                     |
| :--------------------------------- | :-------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`references.tax-nr`**            | `sender.tax-nr`                                                                   | Sender's tax identifier.                                                                                                                                                        |
| **`references.vat-id`**            | `sender.vat-id`                                                                   | Sender's VAT ID.                                                                                                                                                                |
| **`references.seller-tax-nr`**     | `sender.tax-nr`, or `recipient.tax-nr` on a self-billed invoice                   | The seller's tax number (BT-32), which the law requires on the invoice unless its VAT ID is printed (§ 14 Abs. 4 Satz 1 Nr. 2 UStG), with the label of the party it belongs to. |
| **`references.seller-vat-id`**     | `sender.vat-id`, or `recipient.vat-id` on a self-billed invoice                   | The seller's VAT ID (BT-31, Art. 226 No. 3 VAT Directive), with the label of the party it belongs to.                                                                           |
| **`references.buyer-vat-id`**      | `recipient.vat-id`, or `sender.vat-id` on a self-billed invoice                   | The buyer's VAT ID (BT-48), which a reverse charge and an intra-community supply state (Art. 226 No. 4).                                                                        |
| **`references.payee`**             | `payee.name`                                                                      | Who receives the payment instead of the seller, e.g. a factoring company (BG-10).                                                                                               |
| **`references.payment-reference`** | `bank-details` `reference` / `text`, `ctx.payment-reference`, or `ctx.invoice-nr` | Bank transfer purpose (Verwendungszweck), identical to the bank details and ZUGFeRD BT-83.                                                                                      |
| **`references.contact-person`**    | `sender.contact.name`, `sender.contact-name`, or `clerk`                          | Name of the clerk or account manager who issued the invoice.                                                                                                                    |
| **`references.contact-phone`**     | `sender.contact.phone` or `sender.phone`                                          | Direct telephone number of the contact person.                                                                                                                                  |
| **`references.contact-email`**     | `sender.contact.email` or `sender.email`                                          | Email address of the contact person.                                                                                                                                            |

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
