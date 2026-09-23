---
sidebar_position: 3
---

# E-Invoicing (ZUGFeRD / Factur-X)

`invoice-pro` supports generating standardized, compliant electronic invoices using the **ZUGFeRD 2.x / Factur-X 1.0** standard. E-invoicing allows accounting software and tax authorities to automatically ingest, process, and validate invoice data directly from a machine-readable XML payload embedded in your PDF document.

:::warning
ZUGFeRD/Factur-X support in `invoice-pro` is currently **experimental**. Please note the following known limitations:

- **XMP Profile Metadata:** The document's XMP profile does not yet correctly announce the attached `factur-x.xml` file. This can cause some strict validation tools to fail or hang up.
- **Built-in Validation Is Not a Certification:** The template checks your invoice data against the business rules of the selected profile before embedding the XML (see [Validation and Error Reporting](#validation-and-error-reporting)). This catches missing or inconsistent data early, but it does not replace an official validator: verify the generated PDF and XML payload with an external validator (e.g., the [ZUGFeRD Community Validator](https://www.zugferd-community.net/) or other official portals) before using them in production.
- **Reporting Issues:** If you encounter edge cases, schema validation failures, or formatting issues, please report them by opening an issue on our GitHub repository.
  :::

---

## How It Works

Under the hood, when you set a ZUGFeRD profile, the template generates a standard-compliant Cross-Industry Invoice (CII) XML document. It then uses Typst's native PDF attachment capabilities to embed this XML payload inside the PDF:

```typst
pdf.attach(
  "/factur-x.xml",
  xml-bytes,
  relationship: "alternative", // "data" for MINIMUM and BASIC WL
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

## Validation and Error Reporting

Before the XML is embedded, `invoice-pro` checks the invoice data against the business rules of EN 16931, the selected Factur-X profile and, for `"xrechnung"`, the German CIUS (rules `BR-DE-*`). The check does not stop at the first problem: it collects **every** violated rule, so you can fix them all in one go.

By default, the compilation fails with the complete list. Each entry names the rule, the input to look at, what is wrong and how to fix it:

```text
error: assertion failed: The e-invoice (ZUGFeRD / Factur-X, profile XRechnung 3.0) is not valid: 2 errors.
  1. [BR-DE-15] recipient.buyer-reference: XRechnung requires the buyer reference (BT-10), e.g. the Leitweg-ID.
     Hint: Set `buyer-reference` (or `leitweg-id`) on the recipient.
  2. [BR-CO-25] payment-goal: An amount is due, but neither the payment due date (BT-9) nor the payment terms (BT-20) are given.
     Hint: Add `#payment-goal(days: 14)` or set `due-date` on the invoice.
XRechnung is used because seller and buyer are located in Germany (`zugferd: "en16931"`).
Set `zugferd-errors: "report"` on the invoice to list these problems in the document instead.
```

Problems come in two levels:

- **Errors** make the XML invalid for the profile (e.g. a missing invoice number, an unknown unit code or a VAT breakdown that does not add up).
- **Warnings** point out data that is valid but most likely not intended (e.g. an IBAN with a wrong check digit, or an EN 16931 invoice without the electronic addresses Peppol expects). Warnings never stop the compilation.

### The `zugferd-errors` Parameter

The `zugferd-errors` parameter of `invoice` decides what happens with the problems:

| Value               | Behavior                                                                                                                                                                                     |
| :------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"panic"` (default) | Errors stop the compilation with the list shown above (including any warnings). An invoice with warnings only compiles.                                                                      |
| `"report"`          | Nothing stops the compilation. Errors and warnings are listed in a box at the top of the invoice, which is handy while filling in the data in the preview. The XML is embedded nevertheless. |
| `"ignore"`          | The XML is embedded without any check result. Use this only if you validate the XML yourself.                                                                                                |

```typst
#show: invoice.with(
  zugferd: "en16931",
  zugferd-errors: "report", // show the problems in the document while drafting
  // ...
)
```

:::warning
With `"report"` and `"ignore"`, an invoice with errors still carries its (invalid) XML. Switch back to the default `"panic"` before you send an invoice.
:::

### Custom Report Layout

In `"report"` mode, the list is rendered by the theme function `zugferd-report`, which receives the context and the check result. The result contains the resolved `profile` (with `id`, `name` and `promoted`) and the `diagnostics`, an array of dictionaries with the keys `level` (`"error"` or `"warning"`), `rule`, `field`, `message` and `hint`:

```typst
#show: invoice.with(
  theme: themes.DIN-5008().with(
    zugferd-report: (ctx, result) => {
      for d in result.diagnostics [
        - *#d.rule* (#d.level): #d.message
      ]
    },
  ),
  zugferd: "en16931",
  zugferd-errors: "report",
  // ...
)
```

---

## Data Requirements for Compliance

For the generated XML payload to be valid, your input data must satisfy strict standard requirements:

### 1. Party Information

Both the `sender` and `recipient` dictionaries must include:

- **Country:** A country of the `country` module (e.g., `country.de`, `country.fr`, `country.us`), an ISO 3166-1 alpha-2 code (e.g., `"FR"`) or a country created with `country.custom(code: "NO", name: "Norge")`. Without `country`, the party is in the country of the locale region, and a `delivery-address` is in the recipient's country. See the [Country API](./api-reference/invoice/country.md) documentation for details.
- **Address:** ZUGFeRD supports up to three distinct address lines (`ram:LineOne`, `ram:LineTwo`, and `ram:LineThree`). You can specify the address in any of the following polymorphic forms, which are fully supported:
  - **A single string or content:** Maps entirely to `ram:LineOne` (e.g., `"123 Main St"`).
  - **An array of strings or content:** Maps sequentially to the three lines. If there are more than three elements in the array, the remaining elements are joined automatically into `ram:LineThree` using a comma separator (e.g., `("123 Main St", "Suite 100", "4th Floor", "Room 402")` maps to `"123 Main St"`, `"Suite 100"`, and `"4th Floor, Room 402"` respectively).
- **City and Postal Code:** Must be fully specified. To ensure correct splitting for XML generation, you can provide this in one of two ways:
  - **As a String (Parsed Automatically):** Pass the city and postal code as a single string (e.g., `"10115 Berlin"`, `"1012 AB Amsterdam"`) or as content (e.g., `[#plz #ort]`). The post code is recognized in the format of the party's `country` (see [Predefined Countries](./api-reference/invoice/country.md#predefined-countries)). A post code of another format is not taken apart, so check the `country` of the party.
  - **As a Dictionary (Explicit Definition):** Alternatively, explicitly define the name and post-code using a dictionary to prevent any parsing ambiguity. The post code must be a string, so that leading zeros are kept:
    ```typst
    city: (name: "Berlin", post-code: "10115")
    ```
- **Tax Identifiers:**
  - The **sender** should include a `tax-nr` (national tax number) and/or `vat-id` (value-added tax identifier, written with its country prefix, e.g. `"DE123456789"`; spaces are removed).
  - The **recipient** (buyer) should include a `vat-id` if applicable. Reverse charge (`AE`) and intra-community supplies (`K`) require it.
  - The `"minimum"` profile identifies the seller only by its VAT identifier (BT-31), so the **sender** must have a `vat-id` there. Senders with only a `tax-nr` need `"basic-wl"` or higher.

- **Seller Identifier (BT-29):** The buyer must be able to identify the seller (BR-CO-26), by the VAT identifier or a seller identifier. Without a VAT identifier, the `tax-nr` is used as seller identifier. If you have neither, or want to state a different identifier (e.g. your supplier number at the customer, or a company registration number), set `id` on the sender; it does not assert a tax registration. A globally registered identifier (e.g. a GLN) can be given with its ISO/IEC 6523 scheme:

  ```typst
  sender: (
    ...
    id: "70025",
    global-id: (scheme: "0088", id: "4000001123452"), // GLN
  )
  ```

  The same keys on the `recipient` set the buyer identifier (BT-46).

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

  Alternatively, you can define them as direct fields on `sender` (using keys `contact-name`, `phone`, `email`). Missing fields of `contact` fall back to these keys.

- **Buyer Reference / Leitweg-ID (BT-10):** A buyer reference (such as the customer's Leitweg-ID for public sectors) is mandatory under XRechnung. Define this under `buyer-reference` or `leitweg-id` in the `recipient` dictionary:

  ```typst
  recipient: (
    ...
    buyer-reference: "DE123456789-12345-12"
  )
  ```

- **Electronic Addresses & EAS Routing (BT-34 / BT-49):** For routing across networks (such as Peppol), both parties need an electronic address. XRechnung requires them; for the other profiles a missing address is reported as a warning (`"en16931"`) or not at all.
  - **Auto-derivation from VAT ID:** If `vat-id` is specified on the party, the system derives the endpoint from it. The Electronic Address Scheme (EAS) is chosen by the country prefix of the VAT ID:

    | VAT ID prefix | Scheme | VAT ID prefix | Scheme | VAT ID prefix | Scheme |
    | :------------ | :----- | :------------ | :----- | :------------ | :----- |
    | `AT`          | `9914` | `EE`          | `9931` | `LU`          | `9938` |
    | `BE`          | `9925` | `EL` / `GR`   | `9933` | `LV`          | `9939` |
    | `BG`          | `9926` | `ES`          | `9920` | `MT`          | `9943` |
    | `CH`          | `9927` | `FR`          | `9957` | `NL`          | `9944` |
    | `CY`          | `9928` | `GB`          | `9932` | `PL`          | `9945` |
    | `CZ`          | `9929` | `HR`          | `9934` | `PT`          | `9946` |
    | `DE`          | `9930` | `HU`          | `9910` | `RO`          | `9947` |
    |               |        | `IE`          | `9935` | `SI`          | `9949` |
    |               |        | `IT`          | `0211` | `SK`          | `9950` |
    |               |        | `LT`          | `9937` |               |        |

  - **Email Fallback:** Without a VAT ID, or with a VAT ID whose prefix is not in the table (e.g. a Danish `DK` VAT ID), the email address (`contact.email` or `email`) is used with the scheme `EM`. The scheme always follows the VAT ID prefix, never the country of the address.
  - **Manual Override:** You can manually specify a custom electronic address on the party dictionary. A plain email address is accepted as well:
    ```typst
    sender: (
      ...
      electronic-address: (scheme: "0088", id: "4000001123452") // GLN Example
      // or: electronic-address: "invoices@example.com"
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
- **Automatic Mapping:** As a fallback, a string that is exactly a unit code (e.g. `"H87"`) is used as is, and common unit strings (such as `"h"`, `"hrs"`, `"Std."` for hours, or `"days"`, `"Tag"` for days) are mapped to their official codes. Any other string becomes `C62` ("one").

Unit codes are checked against the UN/ECE Recommendation 20 code list. Unit prices are rounded to the fine precision of the locale (`normalize.money-fine`, 4 decimals by default) before the line totals are calculated, and the printed invoice and the XML use this rounded price. For prices with more decimals (e.g. energy tariffs), round them more finely, up to 6 decimals:

```typst
#show: invoice.with(
  locale: locale.de-de.with(
    locale.custom.normalize(money-fine: x => calc.round(x, digits: 6)),
  ),
  // ...
)
```

A `base-quantity` (e.g. a price per 100 pieces) is written as the price base quantity (BT-149); it must be greater than 0.

### 3. Tax Category Codes

Every tax rate must be mapped to a valid **UNTDID 5305** category code. Use the standard functions from the `tax` module:

- Standard VAT/GST: `tax.vat(19%)` (maps to category **S**). Reduced rates are standard rated as well, e.g. `tax.vat(7%)`.
- Zero Rated: `tax.zero()` (maps to category **Z**).
- Tax Exempt: `tax.exempt(grounds: ..)` (maps to category **E**). The `grounds` are mandatory for exempt items (BR-E-10).
- Reverse Charge: `tax.reverse-charge()` (maps to category **AE**). Requires the VAT identifier of the buyer.
- Intra-community Supply: `tax.intra-community()` (maps to category **K**). Requires the VAT identifiers of both parties. Without a `delivery-address`, the buyer's country is stated as deliver-to country; a `delivery-address` without its own `country` is in the buyer's country as well.
- Export: `tax.export()` (maps to category **G**). Requires the seller VAT identifier.
- Outside Scope / Small Business: `tax.outside-scope()` and `tax-exempt-small-biz: true` (map to category **O**). An invoice not subject to VAT carries no VAT identifiers, so the seller is identified by `tax-nr` or `id`. Items of category `O` cannot be mixed with other categories on one invoice.

EN 16931 only knows the categories `S`, `Z`, `E`, `AE`, `K`, `G`, `O`, `L` and `M`. The special constructors in `tax.special` that map to other categories (e.g. `lower-rate`, the margin schemes or split payment `B`) cannot be used for e-invoices.

Where EN 16931 requires an exemption reason (`AE`, `K`, `G`, `O`), the standard text (e.g. "Reverse charge") is used unless you pass your own `grounds`. For the taxed categories (`S`, `Z`, `L`, `M`), `grounds` are printed on the invoice but left out of the XML, which does not allow them there. If the items of one category have different `grounds`, each of them is printed, and the XML joins them with `; ` into the one exemption reason (BT-120) of the category.

`tax: none` on the invoice is not a tax category: the items are printed with 0%, but an e-invoice must say why no VAT is charged, so choose one of the functions above instead.

Document level discounts and surcharges (BG-20, BG-21) belong to a VAT category as well. An absolute amount is split over the categories of the items (see [VAT categories of modifiers](./api-reference/line-items/index.md#vat-categories-of-document-and-bundle-modifiers)); pin it to one with `tax`, e.g. `surcharge([Shipping], amount: 4.90, tax: tax.vat(19%))`.

Avoid using raw percentages (e.g., `19%`) directly on items if you need strict validation, as using the `tax` module functions guarantees the category codes are assigned correctly.

### 4. Gross Prices

With `tax-mode: "inclusive"`, the invoice prints gross prices, while the XML states net amounts as EN 16931 requires. Every line and allowance is converted on its own, and rounding differences of a cent are assigned to the largest line of the VAT category, so the XML adds up exactly to the net and gross totals printed on the invoice.

### 5. Payment Terms and Instructions

- **Due Date or Payment Terms (BT-9 / BT-20):** As long as an amount is due, the invoice must state when to pay (BR-CO-25). Add a [`payment-goal`](./api-reference/components.md#payment-goal) (with `days` or a `date`) or set `due-date` on the invoice. A textual `date` or `due-date` (e.g. `[upon receipt]`) is written as payment terms.
- **Payment Instructions (BG-16):** [`bank-details`](./api-reference/components.md#bank-details) with an `iban` are written as credit transfer (SEPA for EUR invoices). XRechnung requires them (BR-DE-1). IBAN and BIC are written without spaces.

### 6. Payment Reference (BT-83)

The remittance information (`ram:PaymentReference`) always matches the payment reference printed in the [`bank-details`](./api-reference/components.md#bank-details) block and encoded in its EPC-QR code. It is resolved in this order:

1. the `reference` or `text` argument of `bank-details`,
2. the `payment-reference` parameter of `invoice`,
3. the `invoice-nr`.

If `bank-details` explicitly sets `reference: none`, BT-83 is omitted as well.

### 7. Item Identifiers

Line items can carry article identifiers through the `item-id` parameter:

- **Seller's Item Identifier (BT-155):** A plain string such as `item-id: "ART-4711"`, or `(seller: "ART-4711")`, is your own article number.
- **Buyer's Item Identifier (BT-156):** `(buyer: "B-778")` is the buyer's article number.
- **Standard Identifier (BT-157):** `(standard: "4006381333931")` is always declared as a GS1 GTIN (scheme `0160`). Use it only for real EAN/UPC barcode numbers.

The `"basic"` profile only supports the standard identifier. See [The `item-id` Parameter](./api-reference/line-items/index.md#the-item-id-parameter-and-zugferd) for details.

### 8. Document References

`order-nr` (BT-13), `contract-nr` (BT-12), `delivery-note-nr` (BT-16) and `preceding-invoice-nr` (BT-25, e.g. for corrections) are written to the XML where the profile supports them.

---

## Hardcoded Details & Limitations

- **Business Process URN (BT-23):** Whenever using the `"en16931"` or `"xrechnung"` profiles, the Business Process context URN is hardcoded to `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0` (standard billing transaction).
- **EAS Scheme Fallback:** If the prefix of a party's VAT ID has no known scheme and neither a custom `electronic-address` nor an email address is specified, the electronic address block is omitted from the XML payload.
- **Invoice Type Code (BT-3):** Invoices are always written with type code `380` (commercial invoice). Credited lines and negative totals are supported, dedicated credit notes (`381`) are not.
- **Plain Text:** Names, addresses and references given as content are written as their plain text; formatting is dropped.

---

## Complete Example

Here is a full example of a ZUGFeRD-compliant invoice configuration:

```typst
#import "@preview/invoice-pro:0.4.2": *

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

#payment-goal(days: 14)

#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
```

---

## Contributions

The ZUGFeRD implementation in `invoice-pro` was contributed by [Michael Fuchs (theexiile1305)](https://github.com/theexiile1305).
