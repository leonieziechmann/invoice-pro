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
| `"xrechnung"` | XRechnung 3.0      | Identical to `"en16931"` but specifies full compliance with the German XRechnung 3.0 standard (specification identifier).           |

:::info
If `zugferd` is set to `"en16931"` and both the sender and recipient are located in Germany (`DE`), the system automatically promotes the profile internally to `"xrechnung"` to comply with German national e-invoicing requirements (specification identifier).
:::

---

## Data Requirements for Compliance

For the generated XML payload to be valid, your input data must satisfy strict standard requirements:

### 1. Party Information

Both the `sender` and `recipient` dictionaries must include:

- **Country:** Must be a predefined country configuration from the `country` module (e.g., `country.de`, `country.fr`, `country.us`). See the [Country API](./api-reference/invoice/country.md) documentation for details.
- **Address:** ZUGFeRD supports up to three distinct address lines (`ram:LineOne`, `ram:LineTwo`, and `ram:LineThree`). You can specify the address in any of the following polymorphic forms, which are fully supported:
  - **A single string or content:** Maps entirely to `ram:LineOne` (e.g., `"123 Main St"`).
  - **An array of strings or content:** Maps sequentially to the three lines. If there are more than three elements in the array, the remaining elements are joined automatically into `ram:LineThree` using a comma separator (e.g., `("123 Main St", "Suite 100", "4th Floor", "Room 402")` maps to `"123 Main St"`, `"Suite 100"`, and `"4th Floor, Room 402"` respectively).
- **City and Postal Code:** Must be fully specified. To ensure correct splitting for XML generation, you can provide this in one of two ways:
  - **As a String (Parsed Automatically):** Pass the city and postal code as a single string (e.g., `"10115 Berlin"`). If the `country` parameter is configured correctly, the engine will use region-specific parsers to automatically extract the post code and city name.
  - **As a Dictionary (Explicit Definition):** Alternatively, explicitly define the name and post-code using a dictionary to prevent any parsing ambiguity:
    ```typst
    city: (name: "Berlin", post-code: "10115")
    ```
- **Tax Identifiers:**
  - The **sender** should include a `tax-nr` (national tax number) and/or `vat-id` (value-added tax identifier).
  - The **recipient** (buyer) should include a `vat-id` if applicable.

- **Seller Contact (BG-6):** Under German XRechnung rules, the seller must specify contact details. You can define this under the `contact` key of the `sender` dictionary (containing keys `name`, `phone`, `email`):

  ```typst
  sender: (
    ...
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    )
  )
  ```

  Alternatively, you can define them as direct fields on `sender` (using keys `contact-name`, `phone`, `email`).

- **Buyer Reference / Leitweg-ID (BT-10):** A buyer reference (such as the customer's Leitweg-ID for public sectors) is mandatory under XRechnung. Define this under `buyer-reference` or `leitweg-id` in the `recipient` dictionary:

  ```typst
  recipient: (
    ...
    buyer-reference: "DE123456789-12345-12"
  )
  ```

- **Electronic Addresses & EAS Routing (BT-34 / BT-49):** For routing across networks (such as Peppol), both parties require an electronic address.
  - **Auto-derivation from VAT ID:** If `vat-id` is specified on the party, the system automatically derives the Endpoint ID and the Electronic Address Scheme (EAS) prefix based on the country code:
    - Germany (`DE`) -> scheme `9930`
    - Austria (`AT`) -> scheme `9914`
    - Switzerland (`CH`) -> scheme `9927`
    - Belgium (`BE`) -> scheme `9925`
    - France (`FR`) -> scheme `9918`
    - Netherlands (`NL`) -> scheme `9944`
    - UK / United Kingdom (`GB`/`UK`) -> scheme `9932`
    - Ireland (`IE`) -> scheme `9935`
    - Italy (`IT`) -> scheme `9906`
    - Spain (`ES`) -> scheme `9920`
  - **Manual Override:** You can manually specify a custom electronic address on the party dictionary:
    ```typst
    sender: (
      ...
      electronic-address: (scheme: "0088", id: "4000001123452") // GLN Example
    )
    ```

### 2. Standardized Unit Codes

ZUGFeRD requires line-item units to comply with the **UN/ECE Recommendation 20** unit code standard. To ensure a fully compliant configuration, the following approaches are supported (in order of preference):

- **Predefined Units (Recommended):** Use the predefined unit builder functions from the `unit` module (e.g., `unit.hour`, `unit.day`, `unit.piece`, etc.). These are automatically resolved using the document's global locale and map to compliant UN/ECE codes. See the [Unit API Reference](./api-reference/line-items/unit.md) for details.
  ```typst
  unit: unit.hour
  ```
- **Custom / Dictionary Units:** If you have special or custom unit requirements, pass a dictionary containing both the display text and the official UN/ECE code:
  ```typst
  unit: (display: "Piece", code: "C62")
  ```
- **Automatic Mapping:** As a fallback, common unit strings (such as `"h"`, `"hrs"`, `"Std."` for hours, or `"days"`, `"Tag"` for days) are automatically mapped to their official codes.

### 3. Tax Category Codes

Every tax rate must be mapped to a valid **UNTDID 5305** category code. Use the standard functions from the `tax` module:

- Standard VAT/GST: `tax.vat(19%)` (maps to category **S**).
- Tax Exempt: `tax.exempt()` (maps to category **E**).
- Reverse Charge: `tax.reverse-charge()` (maps to category **AE**).
- Intra-community Supply: `tax.intra-community()` (maps to category **K**).

Avoid using raw percentages (e.g., `19%`) directly on items if you need strict validation, as using the `tax` module functions guarantees the category codes are assigned correctly.

---

## Hardcoded Details & Limitations

- **Business Process URN (BT-23):** Whenever using the `"en16931"` or `"xrechnung"` profiles, the Business Process context URN is hardcoded to `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0` (standard billing transaction).
- **EAS Scheme Fallback:** If a party's country code is not in our auto-derivation map and no custom `electronic-address` is specified, the electronic address block is omitted from the XML payload.

---

## Complete Example

Here is a full example of a ZUGFeRD-compliant invoice configuration:

```typst
#import "@preview/invoice-pro:0.3.2": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  // Enable the comfort EN 16931 e-invoicing profile
  zugferd: "en16931",

  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),

  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: (name: "Stuttgart", post-code: "70173"),
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),

  invoice-nr: "INV-2026-102",
  date: datetime(year: 2026, month: 7, day: 8),

  tax-mode: "exclusive",
  tax: tax.vat(19%),
)

= Project Deliverables

#line-items[
  // Using a predefined unit from the unit module (resolved dynamically)
  #item(
    [Senior Software Development],
    quantity: 40,
    unit: unit.hour,
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

---

## Contributions

The ZUGFeRD implementation in `invoice-pro` was contributed by [Michael Fuchs (theexiile1305)](https://github.com/theexiile1305).
