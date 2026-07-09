---
sidebar_position: 4
---

# B2B Invoicing Guide

This guide describes how to configure `invoice-pro` for Business-to-Business (B2B) transactions, outlines the legally required information (non-binding), and provides practical examples for both national and cross-border invoicing.

:::warning
The information provided below is for educational purposes only and does **not** constitute binding legal or tax advice. Invoice requirements can vary based on country, industry, and individual tax status. Always consult a certified tax advisor or accountant to ensure your invoicing practices comply with local regulations.
:::

---

## Key Characteristics of B2B Invoices

B2B invoicing differs significantly from B2C invoicing due to strict tax auditing standards, input VAT deduction rules, and emerging electronic invoicing mandates:

1. **Net Pricing by Default (`tax-mode: "exclusive"`)**:
   In `invoice-pro`, the `tax-mode` parameter defaults to `"exclusive"`. This means all line-item prices are treated as net amounts, and VAT is calculated and added separately at the end. Since businesses can usually reclaim input VAT, quoting net prices is the standard practice in B2B.
2. **Mandatory Tax Identifiers**:
   You must provide your tax number or VAT ID. For transactions within the EU, the buyer's VAT ID is also mandatory to validate tax-exempt or reverse-charge transactions.
3. **Electronic Invoicing Compliance (ZUGFeRD/XRechnung)**:
   Many jurisdictions (such as Germany and France) are transitioning to mandatory electronic invoicing for all domestic B2B transactions. `invoice-pro` natively supports embedding standard-compliant XML metadata using the `zugferd` option.

---

## Mandatory B2B Data Points Explained

When issuing a B2B invoice, specific data points must be provided to ensure the recipient can successfully claim their input tax deduction. Below is an explanation of these fields and how they map to the `invoice` configurations:

| Data Point               | Why it is Important / Legal Meaning                                                                             | Where to Find it                                             | Parameter in `invoice-pro`                                                       |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------- | :------------------------------------------------------------------------------- |
| **Full Supplier Name**   | Identifies the service provider / creditor who is legally contracting.                                          | Trade register or business registration document.            | `sender.name`                                                                    |
| **Supplier Address**     | Defines the official registered office or place of business.                                                    | Business registration.                                       | `sender.address` or `sender.street`, `sender.city`, `sender.country`             |
| **Supplier Tax ID**      | Used by local tax offices for tax assessment. Required if no VAT ID is available.                               | Issued by your local tax authority on registration.          | `sender.tax-nr`                                                                  |
| **Supplier VAT ID**      | Identifies the seller as a registered taxable entity in the EU VAT system. Mandatory for cross-border EU trade. | Applied for and issued by your central tax authority.        | `sender.vat-id`                                                                  |
| **Company Registration** | Legal transparency requirement for corporations (e.g., GmbH, AG) showing register details.                      | Commercial register extract (e.g., _Handelsregisternummer_). | Pass via `sender.extra: ("Handelsregister": "...")`                              |
| **Full Buyer Name**      | Identifies the recipient who is legally authorized to deduct the input VAT.                                     | Client contract, purchase order, or registry search.         | `recipient.name`                                                                 |
| **Buyer Address**        | Defines the billing address of the customer. Must match their official records.                                 | Provided by the customer.                                    | `recipient.address` or `recipient.street`, `recipient.city`, `recipient.country` |
| **Buyer VAT ID**         | Mandatory for zero-rated intra-community supplies and reverse-charge transactions.                              | Provided by the customer (verify via VIES).                  | `recipient.vat-id`                                                               |
| **Buyer Reference**      | A routing ID (e.g., _Leitweg-ID_) used by corporate or public buyers to automatically process invoices.         | Provided by the customer in their purchase order.            | `recipient.buyer-reference`                                                      |
| **Invoice Number**       | Unique, sequential identifier to track invoices chronologically and prevent duplicates.                         | Generated sequentially by your billing system.               | `invoice-nr`                                                                     |
| **Invoice Date**         | Date of document issue. Starts the payment term and assigns the tax period.                                     | The day the invoice is generated.                            | `date` (defaults to today)                                                       |
| **Performance Date**     | The date or period when the services/goods were actually supplied (required for VAT accrual).                   | Delivery notes, timesheets, or milestone reports.            | Add as a reference or inside the subject field.                                  |
| **Tax Rate & Mode**      | Specifies how tax is calculated. Net pricing is default.                                                        | Dictated by local tax law based on the type of service.      | `tax-mode: "exclusive"` and `tax` (using the `tax` module)                       |

---

## B2B Code Examples

Below are two standard B2B configurations showing how to implement these parameters.

### 1. National B2B Invoice (Standard VAT)

For invoicing a business client within the same country (e.g., Germany) where standard VAT applies.

```typst
#import "@preview/invoice-pro:0.3.2": *

#show: invoice.with(
  locale: locale.de-de,
  // Default tax mode is "exclusive" (net prices), so this can be omitted,
  // but you can declare it explicitly for clarity:
  tax-mode: "exclusive",
  tax: tax.vat(19%), // Apply standard German VAT

  sender: (
    name: "Tech Solutions GmbH",
    address: "Software Allee 10",
    city: "80331 München",
    country: country.de,
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "billing@techsolutions.de",
    ),
    extra: (
      "Geschäftsführer": "Max Mustermann",
      "Handelsregister": "Amtsgericht München, HRB 987654",
    ),
  ),

  recipient: (
    name: "Logistics Experts AG",
    address: "Industriestraße 42",
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
  ),

  invoice-nr: "INV-2026-0089",
  date: datetime(year: 2026, month: 7, day: 9),
  references: (
    "Leistungszeitraum": "Juni 2026",
    "Bestellnummer": "PO-99120",
  ),
)

= Projektberatung und Entwicklung

#line-items[
  #item([IT-Architektur Beratung], quantity: 15, unit: unit.hour, price: 120.00)
  #item([Backend Softwareentwicklung], quantity: 40, unit: unit.hour, price: 95.00)
  #item([Server-Setup & Deployment], quantity: 1, unit: unit.piece, price: 450.00)
]

#payment-goal(days: 14)

#bank-details(
  bank: "Münchner Sparkasse",
  iban: "DE89700202001234567890",
  bic: "SADEDE88XXX",
)
```

### 2. Cross-Border B2B Invoice (Reverse Charge)

For invoicing a business client in another EU country where the recipient is responsible for reporting and paying the VAT.

```typst
#import "@preview/invoice-pro:0.3.2": *

#show: invoice.with(
  locale: locale.en-de,
  // We use the reverse-charge tax helper which automatically assigns
  // the correct tax category for e-invoicing and displays standard reverse charge terms.
  tax: tax.reverse-charge(),

  sender: (
    name: "Creative Studio GmbH",
    address: "Designer Weg 5",
    city: "10115 Berlin",
    country: country.de,
    vat-id: "DE123456789", // Mandatory for intra-community supplies
  ),

  recipient: (
    name: "Acme Paris SAS",
    address: "Rue de la Paix 15",
    city: "75002 Paris",
    country: country.fr,
    vat-id: "FR99123456789", // Recipient VAT ID is mandatory to justify Reverse Charge
  ),

  invoice-nr: "INV-2026-0090",
  date: datetime(year: 2026, month: 7, day: 9),
  references: (
    "Performance Period": "01.06.2026 - 30.06.2026",
    "Customer ID": "CUST-PARIS-02",
  ),
)

= UI/UX Redesign Services

#line-items[
  #item([Wireframe & Prototyping], quantity: 20, unit: unit.hour, price: 85.00)
  #item([User Research Sessions], quantity: 8, unit: unit.hour, price: 100.00)
]

#payment-goal(days: 30)

#bank-details(
  bank: "Commerzbank Berlin",
  iban: "DE12370400440532135700",
  bic: "COBA22XXX",
)
```
