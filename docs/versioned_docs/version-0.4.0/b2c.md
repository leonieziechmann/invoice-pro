---
sidebar_position: 5
---

# B2C Invoicing Guide

This guide describes how to configure `invoice-pro` for Business-to-Consumer (B2C) transactions, outlines the legally required information (non-binding) for private customers, and provides practical examples.

:::warning
The information provided below is for educational purposes only and does **not** constitute binding legal or tax advice. Invoice requirements can vary based on country, industry, and individual tax status. Always consult a certified tax advisor or accountant to ensure your invoicing practices comply with local regulations.
:::

---

## Key Characteristics of B2C Invoices

B2C invoices are sent to private individuals (consumers). The legal requirements are generally less strict regarding identifiers than B2B, but consumer protection laws enforce other constraints:

1. **Gross Pricing Required (`tax-mode: "inclusive"`)**:
   Under consumer protection laws in most countries (including the EU/Schengen Area), prices shown to private consumers must be final, gross amounts including all taxes. In `invoice-pro`, you configure this by setting `tax-mode: "inclusive"`. The engine then treats line-item prices as gross amounts and derives the tax share backward automatically.
2. **No VAT ID / Tax Number for the Customer**:
   Private consumers do not have business VAT IDs or commercial registry numbers. Thus, the customer's tax identifiers are completely omitted on B2C invoices.
3. **Simplified Invoices (_Kleinbetragsrechnung_)**:
   For small invoice amounts (e.g., under €250 in Germany), many countries allow simplified invoices. These require fewer details (e.g., the recipient's name and address can often be omitted entirely).

---

## B2C Data Points Explained

Below is an explanation of the fields required on B2C invoices and how they map to the `invoice` configurations:

| Data Point                   | Why it is Important / Legal Meaning                                                                       | Where to Find it                                                                                          | Parameter in `invoice-pro`                                                                         |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| **Full Supplier Name**       | Identifies the business or sole proprietor issuing the invoice.                                           | Official business name or name of the sole proprietor.                                                    | `sender.name`                                                                                      |
| **Supplier Address**         | Declares the official address of the supplier.                                                            | Business registration.                                                                                    | `sender.address` or `sender.street`, `sender.city`, `sender.country`                               |
| **Supplier Tax ID / VAT ID** | Identifies your business for tax auditing. Must be present even if the customer is a consumer.            | Issued by your central or local tax authority.                                                            | `sender.tax-nr` or `sender.vat-id`                                                                 |
| **Recipient Name & Address** | Identifies the private client. (Optional for simplified/small-value invoices, but recommended).           | Provided by the consumer at checkout/order time.                                                          | `recipient.name`, `recipient.address` or `recipient.street`, `recipient.city`, `recipient.country` |
| **Invoice Number**           | Unique, sequential identifier required for your company's bookkeeping.                                    | Generated sequentially by your billing system.                                                            | `invoice-nr`                                                                                       |
| **Invoice Date**             | The day the invoice is issued.                                                                            | The day the invoice is generated.                                                                         | `date` (defaults to today)                                                                         |
| **Tax Mode**                 | Set to `"inclusive"` to present final gross prices to the consumer.                                       | Required by consumer protection laws.                                                                     | `tax-mode: "inclusive"`                                                                            |
| **Tax Rate**                 | Indicates the applicable VAT rate included in the price.                                                  | Dictated by local tax laws of the consumer's country (OSS rules for digital goods) or supplier's country. | `tax` (using the `tax` module)                                                                     |
| **Small Business Exemption** | If you qualify for small business exemptions, you charge 0% tax and must cite the relevant exemption law. | Based on your annual revenue limit (e.g., § 19 UStG in Germany).                                          | `tax-exempt-small-biz: true`                                                                       |

---

## B2C Code Examples

Below are two standard B2C configurations showing how to implement these parameters.

### 1. Standard National B2C Invoice (Gross Pricing)

For invoicing a private consumer within your own country, showing gross prices and calculating VAT retrospectively.

```typst
#import "@preview/invoice-pro:0.4.0": *

#show: invoice.with(
  locale: locale.de-de,
  // B2C requires final gross pricing:
  tax-mode: "inclusive",
  tax: tax.vat(19%), // Applied VAT rate (19% German VAT)

  sender: (
    name: "Web Services & Gear",
    address: "Online Boulevard 8",
    city: "10115 Berlin",
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
  ),

  recipient: (
    name: "Erika Mustermann",
    address: "Rosenweg 12",
    city: "54321 Kundenstadt",
    country: country.de, // Private individual, no tax-nr or vat-id required
  ),

  invoice-nr: "INV-2026-90412",
  date: datetime(year: 2026, month: 7, day: 9),
  subject: [Ihre Bestellung bei Web Services & Gear],
)

= Vielen Dank für Ihre Bestellung!

#line-items[
  #item([Premium Ergonomische Maus], quantity: 1, unit: unit.piece, price: 89.90)
  #item([Mechanische Tastatur (RGB)], quantity: 1, unit: unit.piece, price: 149.00)
  #item([Versicherter Versand], quantity: 1, unit: unit.piece, price: 5.90)
]

#payment-goal(days: 7)

#bank-details(
  bank: "Berliner Volksbank",
  iban: "DE23100900001234567890",
  bic: "BEVODEBBXXX",
)
```

### 2. Small Business Exemption B2C Invoice

For small businesses operating under a local exemption tax scheme (such as the _Kleinunternehmerregelung_ in Germany under § 19 UStG) where no VAT is charged to consumers.

```typst
#import "@preview/invoice-pro:0.4.0": *

#show: invoice.with(
  locale: locale.de-de,
  tax-mode: "inclusive",
  // Enable small business exemption:
  tax-exempt-small-biz: true,
  tax: auto, // Required to be auto when tax-exempt-small-biz is true

  sender: (
    name: "Fotografie & Design Schmidt",
    address: "Kreativstraße 3",
    city: "50667 Köln",
    country: country.de,
    tax-nr: "215/987/65432", // Supplier tax number is required
  ),

  recipient: (
    name: "Thomas Müller",
    address: "Rheinufer 99",
    city: "50996 Köln",
    country: country.de,
  ),

  invoice-nr: "INV-SCHMIDT-1002",
  date: datetime(year: 2026, month: 7, day: 9),
  subject: [Rechnung - Fotoshooting Thomas Müller],
)

= Fotoshootings & Bildbearbeitung

#line-items[
  #item([Portrait-Fotoshooting (2 Std.)], quantity: 1, unit: unit.piece, price: 180.00)
  #item([Bildnachbearbeitung (Premium)], quantity: 5, unit: unit.piece, price: 15.00)
]

#payment-goal(days: 14)

#bank-details(
  bank: "Sparkasse KölnBonn",
  iban: "DE12370400440532135700",
  bic: "COBA22XXX",
)
```
