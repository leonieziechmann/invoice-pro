---
sidebar_position: 6
sidebar_label: E-Invoicing
---

# E-Invoicing (ZUGFeRD / Factur-X)

`invoice-pro` can make every invoice a hybrid e-invoice: a PDF that people read, carrying the same invoice as XML that accounting software and tax authorities process without reading the page. The XML follows the European standard **EN 16931** in the syntax of the UN/CEFACT Cross Industry Invoice (CII), in the profiles of **ZUGFeRD 2.3 / Factur-X 1.0.07** and the German **XRechnung 3.0**.

You write the invoice as usual and choose a profile. `invoice-pro` then checks the invoice data against the rules of the profile, writes the XML from the amounts the invoice prints and attaches it to the PDF.

:::warning
E-invoicing in `invoice-pro` is **experimental**. Please note the following known limitations:

- **Factur-X XMP metadata (Typst limitation):** Typst cannot write custom XMP metadata yet, so the PDF lacks the Factur-X extension schema that announces the attached XML. The XML is valid, but validators that check the PDF itself reject the PDF. See [Factur-X XMP Metadata](./limitations.md#factur-x-xmp-metadata) for an optional post-processing step outside the package.
- **Built-in validation is not a certification:** The check of your invoice data catches missing or inconsistent data early, but it does not replace an official validator: verify the generated PDF and XML with an external validator (e.g., the [ZUGFeRD Community Validator](https://www.zugferd-community.net/) or other official portals) before using them in production.
- **Reporting issues:** If you encounter edge cases, schema validation failures, or formatting issues, please report them by opening an issue on our GitHub repository.

:::

---

## At a Glance

- **One invoice, two forms.** The XML takes every quantity, price, amount and total from the computation that the printed invoice shows, so the PDF and its XML state the same invoice. See [How It Works](./architecture.md).
- **Checked while you compile.** Before the XML is attached, the invoice data is checked against the business rules of EN 16931, the Factur-X profile and XRechnung, and against rules of `invoice-pro` for mistakes the official rules cannot see. Every problem is listed at once, with its official rule id, the input to fix and a hint. See [Validation and Error Reporting](./validation.md).
- **Tested against the official validators.** Every change of `invoice-pro` is tested with the official schemas and Schematron rules, the Mustang validator and the KoSIT validator of XRechnung, on some 900 invoices. Every rule these validators apply is accounted for, profile by profile. See [Testing and Conformance](./conformance.md).
- **Self-contained.** Everything runs inside Typst: no Java, no network and no external tool, in the web app as well as on the command line.
- **Documented limits.** What `invoice-pro` does not support is listed in [Scope and Limitations](./limitations.md), and every business term of EN 16931 with the input that states it in [Business Terms](./invoice-data/business-terms.md).

---

## Profiles

A profile decides how much of the invoice the XML states and which rules apply. Select it with the `zugferd` parameter of `invoice`:

| `zugferd`     | Profile               | Lines | Description                                                                                                                                                                                              |
| :------------ | :-------------------- | :---- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `none`        | –                     | –     | No e-invoice (default).                                                                                                                                                                                  |
| `auto`        | EN 16931 or XRechnung | yes   | **Recommended.** The richest profile the invoice satisfies: `"xrechnung"` for a buyer in Germany if all XRechnung rules are met, otherwise `"en16931"`.                                                  |
| `"minimum"`   | MINIMUM               | no    | The header of the invoice only: the parties, the dates and the totals. A booking aid next to the PDF, which remains the invoice.                                                                         |
| `"basic-wl"`  | BASIC WL              | no    | The header with addresses, payment information, the VAT breakdown and document level allowances and charges, but no invoice lines. A booking aid as well.                                                |
| `"basic"`     | BASIC                 | yes   | A complete e-invoice with invoice lines, in the subset of EN 16931 that Factur-X defines as BASIC.                                                                                                       |
| `"en16931"`   | EN 16931 (COMFORT)    | yes   | The European standard in full: everything `invoice-pro` can state, e.g. contacts, the project reference and the country of origin of items.                                                              |
| `"xrechnung"` | XRechnung 3.0         | yes   | EN 16931 with the German CIUS XRechnung (rules `BR-DE-*`), the standard of German public buyers: it requires the buyer reference (e.g. the Leitweg-ID), the seller contact and the electronic addresses. |

### What Each Profile States

| Invoice data                                                                                                                                                                                         | MINIMUM  | BASIC WL |       BASIC        |      EN 16931      |      XRechnung      |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------: | :------: | :----------------: | :----------------: | :-----------------: |
| Invoice number, date and type, currency, buyer and order reference, seller and buyer with their names and legal registration identifiers, the seller's VAT identifier, the totals and the amount due |    ✓     |    ✓     |         ✓          |         ✓          |          ✓          |
| Postal and electronic addresses, delivery, identifiers of the parties, payee, tax representative                                                                                                     |          |    ✓     |         ✓          |         ✓          |          ✓          |
| Payment instructions and terms, VAT breakdown, document level allowances and charges                                                                                                                 |          |    ✓     |         ✓          |         ✓          |          ✓          |
| Notes, service period, contract, delivery note and preceding invoice references                                                                                                                      |          |    ✓     |         ✓          |         ✓          |          ✓          |
| Invoice lines with quantity, unit, price, VAT, period and note                                                                                                                                       |          |          |         ✓          |         ✓          |          ✓          |
| Seller and buyer contact, buyer trading name, legal information, project reference, BIC, account name, payment card, item identifiers and descriptions, country of origin                            |          |          |                    |         ✓          |          ✓          |
| Rules of the official validation                                                                                                                                                                     | Factur-X | Factur-X | Factur-X, EN 16931 | Factur-X, EN 16931 | EN 16931, XRechnung |

What the invoice prints beyond its profile stays on the page only: the validation lists such an input as a warning (`IP-PROFILE-01`) and names the lowest profile that states it.

### Choosing a Profile

- **`auto` for most invoices.** For a buyer in Germany, `invoice-pro` tries XRechnung 3.0 and uses it if the invoice meets all XRechnung rules (for example, it needs the buyer reference or Leitweg-ID). Otherwise, and for buyers outside Germany, it uses `"en16931"`. The XRechnung rules that were not met are listed as warnings, which `zugferd-errors: "report"` shows, and the report names the chosen profile.
- **`"xrechnung"` for German public buyers.** An explicit profile is always used as given, so a missing Leitweg-ID is an error instead of a fallback to EN 16931. Likewise, `"en16931"` stays EN 16931 between German parties. Earlier versions switched it to XRechnung automatically; use `auto` for that now.
- **MINIMUM and BASIC WL** state no invoice lines, so their XML supplements the PDF instead of replacing it, and `invoice-pro` attaches it as supplementary data. German law does not accept them as e-invoices (BMF letter of 15 October 2024): for e-invoices between businesses in Germany, use `auto`, `"en16931"` or `"xrechnung"`.

---

## Getting Started

1. **Choose a profile:** set `zugferd: auto` (or another profile) on the invoice.
2. **Give the data the profile needs:** both parties need their name, address and country, the seller its VAT identifier or tax number, and payment terms or a due date must say when to pay. If data every invoice needs is missing, the invoice renders as a draft that marks it and attaches no XML (see [Validation](../api-reference/invoice/validation.md)); what the profile needs beyond it stops the compilation with a list of what to add (see [Validation and Error Reporting](./validation.md)). [Invoice Data](./invoice-data/index.md) explains every input.
3. **Compile as PDF/A-3b.** To produce a valid ZUGFeRD hybrid PDF, you **must** compile your Typst document to conform to the **PDF/A-3** standard (`a-3b`). This is a hard requirement for attaching files inside a PDF/A compliant document:

   ```bash
   typst compile --pdf-standard=a-3b invoice.typ output.pdf
   ```

   If you do not specify the `--pdf-standard=a-3b` flag, the compile process may succeed, but the resulting document will not be fully compliant with ZUGFeRD/Factur-X specifications.

The recipient's software finds the attached `factur-x.xml` (or `xrechnung.xml`) and reads the invoice from it. XRechnung is mostly exchanged as the XML file itself: see [The XML on Its Own](./limitations.md#the-xml-on-its-own) for how to extract it. A [complete example](#complete-example) is at the end of this page.

### When the Data Is Incomplete

Missing invoice data comes first: under the default `validation: "draft"`, an invoice without data the law requires on every invoice (for example its number or the seller's VAT identifier) renders as a draft with a report page, and its XML is withheld until the data is complete; `validation: "strict"` stops the compilation instead (see [Validation](../api-reference/invoice/validation.md)). Once that data is complete, the rules of the e-invoice are checked, and the `zugferd-errors` parameter of `invoice` decides what happens with the problems they find:

| Value               | Behavior                                                                                                                                                                     |
| :------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"panic"` (default) | Errors stop the compilation with the complete list. An invoice with warnings only compiles.                                                                                  |
| `"report"`          | The problems are listed in a box at the top of the invoice (the `zugferd-report` part of the theme), which helps while you fill in the data; the XML is attached as a draft. |
| `"ignore"`          | The XML is attached whatever its errors. Use this only if you validate the XML yourself.                                                                                     |

See [Validation and Error Reporting](./validation.md) for the details.

---

## Where to Find What

| Page                                              | What it covers                                                                                                                                                                |
| :------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [How It Works](./architecture.md)                 | The architecture: how the XML is made from the computed invoice, the principles that keep the PDF and the XML the same invoice, and how the XML is attached.                  |
| [Validation and Error Reporting](./validation.md) | What is checked while you compile, the error listing, `zugferd-errors`, the report in the document, the details the printed invoice must show and the rules of `invoice-pro`. |
| [Testing and Conformance](./conformance.md)       | How the XML is tested against the official schemas and validators, the conformance corpus and the coverage of every official rule.                                            |
| [Scope and Limitations](./limitations.md)         | What is not supported, fixed details of the XML and the Factur-X XMP metadata.                                                                                                |
| [Invoice Data](./invoice-data/index.md)           | The inputs of the e-invoice, topic by topic: parties, line items, taxes, payment, document details and every business term of EN 16931.                                       |

---

## Complete Example

Here is a full example of a ZUGFeRD-compliant invoice configuration:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
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

#payment-terms(days: 14)

#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
```

---

## Contributions

The ZUGFeRD implementation in `invoice-pro` was contributed by [Michael Fuchs (theexiile1305)](https://github.com/theexiile1305).
