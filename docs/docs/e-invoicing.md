---
sidebar_position: 3
---

# E-Invoicing (ZUGFeRD / Factur-X)

`invoice-pro` supports generating standardized, compliant electronic invoices using the **ZUGFeRD 2.x / Factur-X 1.0** standard. E-invoicing allows accounting software and tax authorities to automatically ingest, process, and validate invoice data directly from a machine-readable XML payload embedded in your PDF document.

:::warning
ZUGFeRD/Factur-X support in `invoice-pro` is currently **experimental**. Please note the following known limitations:

- **XMP Profile Metadata:** The document's XMP profile does not yet correctly announce the attached `factur-x.xml` file. This can cause some strict validation tools to fail or hang up.
- **No Self-Validation:** The template code does not validate your final document structure for full regulatory compliance. You **must** verify the generated PDF and XML payload using an external validator (e.g., the [ZUGFeRD Community Validator](https://www.zugferd-community.net/) or other official portals) before using them in production.
- **Reporting Issues:** If you encounter edge cases, schema validation failures, or formatting issues, please report them by opening an issue on our GitHub repository.
  :::

---

## How It Works

Under the hood, when you set a ZUGFeRD profile, the template generates a standard-compliant Cross-Industry Invoice (CII) XML document. It then uses Typst's native PDF attachment capabilities to embed this XML payload inside the PDF:

```typst
pdf.attach(
  "/factur-x.xml",
  xml-bytes,
  relationship: "alternative",
  mime-type: "text/xml",
  description: "ZUGFeRD / Factur-X invoice data",
)
```

The recipient's software detects this embedded `/factur-x.xml` file and extracts all metadata without needing optical character recognition (OCR) on the visual layout.

---

## Compilation Requirements

To produce a valid ZUGFeRD hybrid PDF, you **must** compile your Typst document to conform to the **PDF/A-3** standard (`a-3b`). This is a hard requirement for attaching files inside a PDF/A compliant document.

Compile your document using the following command:

```bash
typst compile --pdf-standard=a-3b invoice.typ output.pdf
```

If you do not specify the `--pdf-standard=a-3b` flag, the compile process may succeed, but the resulting document will not be fully compliant with ZUGFeRD/Factur-X specifications.

---

## ZUGFeRD Profiles

You can select a profile by setting the `zugferd` parameter in your root `invoice` config. Choose the profile that best fits your regional and business requirements:

| Profile Value | Profile Name       | Description                                                                                                                         |
| :------------ | :----------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| `none`        | None               | Disables XML generation and attachment (default).                                                                                   |
| `"minimum"`   | Minimum            | Header-level metadata only (seller, buyer, date, total). Does not include any line items. Primarily used for cross-border invoices. |
| `"basic-wl"`  | Basic WL           | Header-level metadata plus payment information. No line items are included.                                                         |
| `"basic"`     | Basic              | Full invoice header and payment information, along with basic line items.                                                           |
| `"en16931"`   | Comfort / EN 16931 | Fully compliant with the EN 16931 European e-invoicing standard, including detailed line-item details. **Recommended.**             |

---

## Data Requirements for Compliance

For the generated XML payload to be valid, your input data must satisfy strict standard requirements:

### 1. Party Information

Both the `sender` and `recipient` dictionaries must include:

- **Country:** Must be a valid two-letter ISO country code (e.g., `"DE"`, `"FR"`, `"US"`).
- **City and Postal Code:** Must be fully specified. To ensure correct splitting for XML generation, you can define your city as a dictionary:
  ```typst
  city: (name: "Berlin", post-code: "10115")
  ```
- **Tax Identifiers:**
  - The **sender** should include a `tax-nr` (national tax number) and/or `vat-id` (value-added tax identifier).
  - The **recipient** (buyer) should include a `vat-id` if applicable.

### 2. Standardized Unit Codes

ZUGFeRD requires line-item units to comply with the **UN/ECE Recommendation 20** unit code standard.

- **Automatic Mapping:** Common strings in `invoice-pro` (like `"h"`, `"hrs"`, `"Std."` for hours, or `"days"`, `"Tag"` for days) are automatically mapped to official codes (`HUR`, `DAY`, etc.).
- **Manual / Custom Codes:** If you have custom units, pass them as a dictionary containing both the display text and the official UN/ECE code:
  ```typst
  unit: (display: "Piece", code: "C62")
  ```

### 3. Tax Category Codes

Every tax rate must be mapped to a valid **UNTDID 5305** category code. Use the standard functions from the `tax` module:

- Standard VAT/GST: `tax.vat(19%)` (maps to category **S**).
- Tax Exempt: `tax.exempt()` (maps to category **E**).
- Reverse Charge: `tax.reverse-charge()` (maps to category **AE**).
- Intra-community Supply: `tax.intra-community()` (maps to category **K**).

Avoid using raw percentages (e.g., `19%`) directly on items if you need strict validation, as using the `tax` module functions guarantees the category codes are assigned correctly.

---

## Complete Example

Here is a full example of a ZUGFeRD-compliant invoice configuration:

```typst
#import "@preview/invoice-pro:0.3.2": *

#show: invoice.with(
  // Enable the comfort EN 16931 e-invoicing profile
  zugferd: "en16931",

  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: (name: "München", post-code: "80331"),
    country: "DE",
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
  ),

  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: (name: "Stuttgart", post-code: "70173"),
    country: "DE",
    vat-id: "DE987654321",
  ),

  invoice-nr: "INV-2026-102",
  date: datetime(year: 2026, month: 7, day: 8),

  tax-mode: "exclusive",
  tax: tax.vat(19%),
)

= Project Deliverables

#line-items[
  // Using an automatically mapped unit
  #item(
    [Senior Software Development],
    quantity: 40,
    unit: "h",
    price: 120.00,
  )

  // Using a custom/dictionary unit code
  #item(
    [On-site Workshop Bundle],
    quantity: 1,
    unit: (display: "Pkg.", code: "C62"),
    price: 1500.00,
  )

  // Applying standard tax exemption
  #item(
    [VAT-Free Educational Materials],
    quantity: 5,
    unit: (display: "Pcs.", code: "C62"),
    price: 45.00,
    tax: tax.exempt(grounds: "Section 4 No. 21 UStG"),
  )
]

#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
```
