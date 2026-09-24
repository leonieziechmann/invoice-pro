---
sidebar_position: 3
---

# E-Invoicing (ZUGFeRD / Factur-X)

`invoice-pro` supports generating standardized, compliant electronic invoices using the **ZUGFeRD 2.x / Factur-X 1.0** standard. E-invoicing allows accounting software and tax authorities to automatically ingest, process, and validate invoice data directly from a machine-readable XML payload embedded in your PDF document.

:::warning
ZUGFeRD/Factur-X support in `invoice-pro` is currently **experimental**. Please note the following known limitations:

- **Factur-X XMP Metadata (Typst limitation):** Typst cannot write custom XMP metadata yet, so the PDF lacks the Factur-X extension schema that announces the attached XML (`factur-x.xml`, or `xrechnung.xml` in the XRechnung profile). The embedded XML is valid, but validators that check the PDF itself reject the PDF. See [Factur-X XMP Metadata](#factur-x-xmp-metadata) for an optional post-processing step outside the package.
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

The recipient's software detects this embedded `/factur-x.xml` file and extracts all metadata without needing optical character recognition (OCR) on the visual layout. In the `"xrechnung"` profile, the file is named `/xrechnung.xml`, as ZUGFeRD 2.3 names the XML of its XRECHNUNG profile (and as Mustang embeds it). Earlier versions named it `factur-x.xml` in every profile.

If the XML has errors and you let the invoice compile anyway with `zugferd-errors: "report"`, the XML is attached as a draft instead: named `invoice-draft.xml` and with the relationship `"data"` (see [The `zugferd-errors` Parameter](#the-zugferd-errors-parameter)).

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

| Profile Value | Profile Name       | Description                                                                                                                                             |
| :------------ | :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `none`        | None               | Disables XML generation and attachment (default).                                                                                                       |
| `auto`        | Automatic          | The richest profile the invoice satisfies: `"xrechnung"` for a buyer in Germany if all XRechnung rules are met, otherwise `"en16931"`. **Recommended.** |
| `"minimum"`   | Minimum            | Header-level metadata only (seller, buyer, date, total). Does not include any line items. Primarily used for cross-border invoices.                     |
| `"basic-wl"`  | Basic WL           | Header-level metadata plus payment information. No line items are included.                                                                             |
| `"basic"`     | Basic              | Full invoice header and payment information, along with basic line items.                                                                               |
| `"en16931"`   | Comfort / EN 16931 | Fully compliant with the EN 16931 European e-invoicing standard, including detailed line-item details.                                                  |
| `"xrechnung"` | XRechnung 3.0      | Identical to `"en16931"` but specifies full compliance with the German XRechnung 3.0 standard (specification identifier).                               |

:::info
With `zugferd: auto`, `invoice-pro` chooses the richest profile the invoice satisfies. For a buyer in Germany it tries XRechnung 3.0 and uses it if the invoice meets all XRechnung rules (for example, it needs the buyer reference or Leitweg-ID). Otherwise, and for buyers outside Germany, it uses `"en16931"`. The XRechnung rules that were not met are listed as warnings, which `zugferd-errors: "report"` shows, and the report names the chosen profile. An explicit profile is always used as given: `"en16931"` stays EN 16931 between German parties, too. Earlier versions switched it to XRechnung automatically; use `auto` for that now.
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
Set `zugferd-errors: "report"` on the invoice to list these problems in the document instead.
```

Problems come in two levels:

- **Errors** make the XML invalid for the profile (e.g. a missing invoice number, an unknown unit code or a VAT breakdown that does not add up), or the invoice wrong in a way the official validators cannot see (see below).
- **Warnings** point out data that is valid but most likely not intended (e.g. an EN 16931 invoice without the electronic addresses Peppol expects, a key of a party that `invoice-pro` does not know, or a unit code that is also a common abbreviation of another unit). Warnings never stop the compilation.

For XRechnung, the seller contact phone number must contain at least three digits (`BR-DE-27`), and the email address must match the pattern of the XRechnung Schematron (`BR-DE-28`, ASCII only: write a domain with umlauts in punycode, e.g. `info@xn--mller-bau-q9a.de` for `info@müller-bau.de`). XRechnung only warns about these two rules, and the KoSIT validator accepts such an invoice, but other validators, such as Mustang, reject it. `invoice-pro` therefore reports them as errors.

Besides the official rules (`BR-*`, `BR-DE-*`, `PEPPOL-*`, `CII-SR-*`), `invoice-pro` checks some rules of its own, whose ids start with `IP-`. Here it is stricter than the official validators: they accept the XML, but a value the invoice states would be lost or wrong, or the law requires more than the profile checks.

| Rule            | Level   | Checks                                                                                                                                                                                                                                                                             |
| :-------------- | :------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `IP-COUNTRY-01` | error   | A party without `country` whose VAT identifier was issued by another country: the country of the locale would be written (e.g. "DE" for the Austrian VAT ID "ATU12345678"). Set `country` on the party, also for a foreign VAT registration.                                       |
| `IP-ADDR-01`    | error   | A city line with a number of three or more digits, but no post code in the format of the party's country (e.g. "1012 Amsterdam" instead of "1012 AB Amsterdam"): the post code would be missing, and the number would be written into the city name.                               |
| `IP-ID-01`      | error   | An identifier of the [`id` module](./api-reference/invoice/identifiers.md) whose format or check digit is wrong, e.g. a SIRET with a typo. `id.custom(..)` takes an identifier unchecked.                                                                                          |
| `IP-ID-02`      | error   | Two values for one party identifier, of which only one can be written: a `global-id` without scheme next to `id`, a `location-id` next to `id` of the delivery address, or two identifiers with scheme.                                                                            |
| `IP-ID-03`      | error   | An identifier given for a field it does not belong to: a Leitweg-ID as party identifier or legal registration identifier, another identifier as `leitweg-id`, a GLN or D-U-N-S number as `legal-id`, or a register number as `id`.                                                 |
| `IP-KEY-01`     | warning | A key of `sender`, `recipient`, `delivery-address`, `sender.tax-representative` or `payee` that `invoice-pro` does not know: its value is not written into the e-invoice.                                                                                                          |
| `IP-KEY-02`     | error   | A misspelled key the e-invoice reads, or another name of it (e.g. `vatId`, `vat_id`, `ustid`, `uid`, `e-mail`, `siret` or `zip`): its value would be missing without notice.                                                                                                       |
| `IP-PROFILE-01` | warning | An input the profile cannot state, e.g. the buyer trading name (BT-45) in `"basic"`, or `notes`, a `payee` or the method of `paid` in `"minimum"`: the invoice may print it, but it is not written into the e-invoice. The hint names the lowest profile that states it.           |
| `IP-VAT-226`    | error   | An intra-community supply (`K`) or a cross-border reverse charge (`AE`) without the buyer VAT identifier (Art. 226 No. 4 VAT Directive), which the official rules miss: in BASIC WL (no invoice lines) and with a buyer `legal-id`; a tax representative without address (No. 15). |
| `IP-VAT-138`    | warning | An intra-community supply (`K`) to a buyer whose VAT identifier was not issued by an EU member state (or "XI" for Northern Ireland).                                                                                                                                               |
| `IP-TAX-01`     | error   | `tax: none` in an e-invoice: the items would be declared as zero rated (`Z`). Use `tax.zero()`, `tax.exempt(grounds: ..)`, `tax.outside-scope()` or `tax-exempt-small-biz`.                                                                                                        |
| `IP-TAX-02`     | error   | A VAT exemption reason code (BT-121, `code` of the `tax` module) of another VAT category, e.g. `"VATEX-EU-IC"` on an exemption (`E`), or on a taxed category (`S`, `Z`, `L`, `M`). See [Tax Category Codes](#3-tax-category-codes).                                                |
| `IP-TAX-03`     | warning | Items of one VAT category and rate with different exemption reason codes: EN 16931 states one code per VAT group, so the reasons are stated as text (BT-120) only.                                                                                                                 |
| `IP-TAX-04`     | error   | An exemption (`E`) with an exemption reason code but without `grounds`: the printed invoice must state why no VAT is charged (§ 14 Abs. 4 Satz 1 Nr. 8 UStG, Art. 226 No. 11 of the VAT Directive).                                                                                |
| `IP-PRINT-02`   | error   | Amounts printed in another currency than the invoice currency (BT-5), e.g. a custom locale that prints "zł" while the XML states EUR.                                                                                                                                              |
| `IP-DEC-01`     | error   | A VAT rate with more than 4 decimals, which the XML cannot state exactly (and which could collide with another VAT group).                                                                                                                                                         |
| `IP-PAY-01`     | error   | An IBAN with wrong check digits or format in `bank-details` or as `debtor-iban` of `direct-debit`, where `BR-DE-19` and `BR-DE-20` do not check it (outside XRechnung, or an invoice not in euro).                                                                                 |
| `IP-PAY-02`     | error   | A SEPA creditor identifier (BT-90) of `direct-debit` with wrong check digits or format.                                                                                                                                                                                            |
| `IP-PAY-03`     | error   | Two kinds of payment means that the official rules accept together, e.g. `bank-details` next to `card-payment`: an invoice states one payment means (BT-81), so that the buyer does not pay twice.                                                                                 |
| `IP-UNIT-01`    | warning | A unit code used verbatim that is also a common German abbreviation of another unit (`STK`, `PAL`, `FL`, `GL`, `KT`).                                                                                                                                                              |
| `IP-DOC-01`     | error   | A subject that names another kind of document than an invoice (e.g. "Gutschrift", "Angebot", "Credit note", "Devis") without `document-type`: the e-invoice would state a commercial invoice that asks the buyer to pay. See [Document Type](#9-document-type-bt-3).               |
| `IP-DOC-02`     | error   | A corrected invoice (`document-type: "corrected"`) without `preceding-invoice-nr`: it replaces an invoice, which the VAT Directive (Art. 219) requires it to name. XRechnung checks it as `BR-DE-26`.                                                                              |
| `IP-DOC-03`     | error   | A credit note with a negative total: it states the credited amounts as positive amounts, so it would ask the buyer to pay.                                                                                                                                                         |
| `IP-DOC-04`     | warning | An invoice with a negative total: valid, but a credit note (`document-type: "credit-note"`) is the document for a credit.                                                                                                                                                          |
| `IP-PERIOD-01`  | error   | A printed service period that is not the one the XML states: another date, or a text of its own where the XML states the invoice date. A text of its own besides dated items or a `service-period` is a warning. See [Service Period](#10-service-period-bt-72--bg-14).            |
| `IP-PERIOD-02`  | warning | The date of an item outside the `service-period` of the invoice. XRechnung checks it for an invoicing period (BG-14) as `PEPPOL-EN16931-R110` and `R111`. See [Item Notes, Periods and Country of Origin](#12-item-notes-periods-and-country-of-origin).                           |
| `IP-PERIOD-03`  | error   | The printed invoice does not show the date of the supply, which German law requires on every invoice but a small-amount invoice; for a seller elsewhere a warning where it is not the invoice date. See [Printed Details](#printed-details).                                       |
| `IP-PRINT-03`   | error   | The XML states the seller's VAT identifier (BT-31) or tax number (BT-32), one of which the law requires on the invoice, but the printed invoice shows neither. See [Printed Details](#printed-details).                                                                            |

### The XML Write Guard

The validator checks the invoice data; a second check, the write guard, checks the XML itself while it is written, against tables compiled from the official artefacts of the profile (the Factur-X 1.0.07 XSD and Schematron, the CEN Schematron of EN 16931 and, for `"xrechnung"`, the XRechnung 3.0 Schematron). For every e-invoice `invoice-pro` attaches without errors (with `zugferd-errors: "ignore"`, it attaches the XML whatever the checks find), it guarantees:

- **Structure (G1):** every element is known to the profile's schema at its position and not marked as not used there by the Factur-X Schematron; the elements are in schema order and number (`maxOccurs` and the counts of the Schematron); every element the schema or a rule of the Schematron without a condition on values requires is there with its text (an element without text counts as missing), e.g. for `"xrechnung"` the city and post code of the addresses, the contact of the seller, the buyer reference and the rate of each VAT breakdown; every required attribute is there, and no other attribute.
- **Values (G2):** decimals, indicators and dates have their lexical form, and dates in the format `102` name a day of the calendar; amounts have at most the decimals the `BR-DEC-*` rules allow; every code is in the code list of its position. Where several validators apply, the code must be in the list of each of them, e.g. a country code in the list of the Factur-X Schematron and in the one of EN 16931. Every tax element (the VAT of a line, of an allowance or charge, and each VAT breakdown) has what its VAT category requires: a rate above 0 for `S`, `L` and `M`, the rate 0 for `Z`, `E`, `AE`, `K` and `G`, and none for `O` (`BR-S-05` and the like); a VAT breakdown has a rate unless its category is `O` (`BR-48`), the VAT amount 0 for `Z`, `E`, `AE`, `K`, `G` and `O`, an exemption reason for `E`, `AE`, `K`, `G` and `O`, and none for `S`, `Z`, `L` and `M` (`BR-E-09`, `BR-E-10` and the like).
- **Well-formed (G4):** Typst's XML parser reads the bytes that are attached as one `CrossIndustryInvoice` document.

The guard does not change the XML: the file is the same with or without it. What it finds is added to the diagnostics, as errors, and `zugferd-errors` treats them like the validator's. A problem the validator reports already (the same rule or the same input) is not listed twice. Since the validator checks every input before, a finding of the guard is a bug of `invoice-pro`: if the guard finds something the validator does not, each finding is listed with the hint to report it; if the validator reports errors, the guard's other findings are one entry, as they may follow from those errors. A finding names the official rule of the check where there is one (e.g. `BR-CL-14` for a country code), and otherwise a rule of the guard:

| Rule          | Checks                                                                                                                  |
| :------------ | :---------------------------------------------------------------------------------------------------------------------- |
| `IP-GUARD-00` | Summarizes the guard's findings next to errors of the validator.                                                        |
| `IP-GUARD-01` | An element the profile's schema does not know at its position, or text where it expects elements.                       |
| `IP-GUARD-02` | An element out of the order of the schema.                                                                              |
| `IP-GUARD-03` | An element more often than the schema or the Schematron allows.                                                         |
| `IP-GUARD-04` | A required element that is missing or has no text.                                                                      |
| `IP-GUARD-05` | An element or attribute the Factur-X Schematron of the profile marks as not used.                                       |
| `IP-GUARD-06` | An attribute the schema does not allow, or a required one that is missing.                                              |
| `IP-GUARD-07` | A value outside its lexical form (e.g. `1,50` as a decimal) or a code outside its list, where no official rule says so. |
| `IP-GUARD-08` | A date in the format `102` that names no day of the calendar (e.g. `20260230`), where no official rule checks it.       |
| `IP-GUARD-09` | An invalid name, a missing namespace declaration, or not exactly one root element: the XML may not be well-formed.      |

The guard checks what the schema, the code lists and the rules of the VAT categories say about each element, not the business rules (sums, conditions between different parts of the invoice, and elements required only under such a condition, e.g. an identifier of the seller in `BR-CO-26`), which remain the validator's. It is stricter than the official validators in a few documented places: it rejects the elements the Factur-X Schematron marks as not used (Mustang ignores those reports), dates that name no day, a required element without text also where a rule only asks for the element, and any element `invoice-pro` never writes; and where a rule of the CEN Schematron may be taken over by a rule of higher priority only under a condition on values, it applies the rule anyway. Its tables follow the artefacts of the Mustang CLI 2.14.0, which `invoice-pro` pins: IPSI (`M`) at 0 % is rejected there (`BR-AG-05` tests a rate above 0), while the newer EN 16931 Schematron of KoSIT's XRechnung configuration accepts it.

### Coverage of the Official Rules

The tests of `invoice-pro` account for every rule of the official validators, profile by profile: the rule ids of the Factur-X, EN 16931 and XRechnung Schematron files that the Mustang CLI 2.14.0 and KoSIT's XRechnung configuration apply to each profile. Each rule is either reported by `invoice-pro`, enforced by the write guard, excluded by construction (e.g. a negative price is written as a negative quantity), or unable to occur because `invoice-pro` never writes the element it tests (e.g. a gross price). For every rule it reports, a test invoice in each profile where it counts proves that the official validators of the profile reject it with the rule and that `invoice-pro` names the same one; where one mistake breaks several rules at once, `invoice-pro` may name another of them (e.g. `BR-S-02` for the XRechnung rule `BR-DE-16`). The coverage is not complete yet: the rules in the column "Open" are not handled, or `invoice-pro` reports them under another id.

[//]: # "rule-coverage table: generated by tools/zugferd/rule_coverage.py --update-docs"

| Profile   | Rule ids | Reported by invoice-pro | Enforced by the guard | Excluded by construction | Cannot occur | Open |
| :-------- | -------: | ----------------------: | --------------------: | -----------------------: | -----------: | ---: |
| MINIMUM   |       46 |                       6 |                    40 |                        0 |            0 |    0 |
| BASIC WL  |      196 |                      56 |                   117 |                       14 |            7 |    2 |
| BASIC     |      851 |                      72 |                   713 |                       41 |           23 |    2 |
| EN 16931  |      905 |                      73 |                   734 |                       54 |           40 |    4 |
| XRechnung |      885 |                     105 |                   646 |                       62 |           67 |    5 |

Open: `BR-B-01` (BASIC, EN 16931, XRechnung), `BR-B-02` (BASIC, EN 16931, XRechnung), `BR-O-03` (BASIC WL), `BR-O-04` (BASIC WL), `CII-SR-467` (EN 16931, XRechnung), `CII-SR-470` (EN 16931, XRechnung), `PEPPOL-EN16931-R120` (XRechnung).

[//]: # "end of the rule-coverage table"

### The `zugferd-errors` Parameter

The `zugferd-errors` parameter of `invoice` decides what happens with the problems:

| Value               | Behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| :------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"panic"` (default) | Errors stop the compilation with the list shown above (including any warnings). An invoice with warnings only compiles.                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `"report"`          | Errors and warnings are listed in a box at the top of the invoice instead of stopping the compilation, which is handy while filling in the data in the preview. If the theme shows no report, errors stop the compilation as with `"panic"` (see [Custom Report Layout](#custom-report-layout)). The XML of an invoice with errors is attached as a draft: as `invoice-draft.xml` instead of `factur-x.xml` (or `xrechnung.xml`) and with the relationship `"data"`, so that no receiving software takes it for the e-invoice. With warnings only, the XML is attached as usual. |
| `"ignore"`          | The check is skipped on purpose: the XML is attached as usual (`factur-x.xml` or `xrechnung.xml`, relationship of the profile), whatever its errors. It may then be invalid, and you are responsible for it. Use this only if you validate the XML yourself, e.g. when a recipient explicitly accepts a deviation.                                                                                                                                                                                                                                                               |

A missing or invalid IBAN in [`bank-details`](./api-reference/components.md#bank-details), or an invalid IBAN or creditor identifier of a [`direct-debit`](./api-reference/components.md#direct-debit), makes the printed invoice wrong as well, so it stops the compilation with a message naming it, also with `"ignore"`. With `"report"`, it is marked where it is printed instead (a placeholder takes the place of the EPC-QR code), and the report lists it as an error (`BR-DE-19` or `BR-DE-20` in XRechnung, `IP-PAY-01` or `IP-PAY-02` otherwise), so the XML is attached as a draft.

```typst
#show: invoice.with(
  zugferd: "en16931",
  zugferd-errors: "report", // show the problems in the document while drafting
  // ...
)
```

:::warning
An invoice with errors is not a valid e-invoice. With `"report"`, it carries its XML only as the draft `invoice-draft.xml`; with `"ignore"`, it carries the invalid XML as the e-invoice (`factur-x.xml` or `xrechnung.xml`). Switch back to the default `"panic"` before you send an invoice.
:::

### Custom Report Layout

In `"report"` mode, the list is rendered by the theme function `zugferd-report`, which receives the context and the check result. The result contains the resolved `profile` (with `id`, `name`, `automatic` and, for `auto`, the `skipped` profiles) and the `diagnostics`, an array of dictionaries with the keys `level` (`"error"` or `"warning"`), `rule`, `field`, `message` and `hint`:

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

Whatever the function returns is placed above the invoice body as content (a string works as well). A theme can do without the list with `zugferd-report: none`. Errors must not go unnoticed, though: if the theme shows no report (`none`, or a function that returns `none` or empty content), errors stop the compilation as with `"panic"`, and only warnings are left out. Any other value is rejected with an error naming `theme::zugferd-report`.

### Printed Details

The printed invoice and its XML are one invoice, so the printed invoice shows what the XML states and the law requires on an invoice:

- **The seller's tax number or VAT identifier** (`IP-PRINT-03`, § 14 Abs. 4 Satz 1 Nr. 2 UStG, Art. 226 No. 3 of the VAT Directive): an error if the XML states the seller's VAT identifier (BT-31) or tax number (BT-32), but the printed invoice shows neither. A small-amount invoice of at most 250 euros needs neither by German law (§ 33 UStDV), but it shows what its XML states as well.
- **The date of the supply** (`IP-PERIOD-03`): for a seller in Germany an error, as the law requires it on every invoice, also when it is the date of the invoice (§ 14 Abs. 4 Satz 1 Nr. 6 UStG), except on a small-amount invoice of at most 250 euros that is no intra-community supply or reverse charge (§ 33 UStDV). For a seller elsewhere, and on a small-amount invoice, it is a warning where the date of the supply is not the date of the invoice (Art. 226 No. 7 of the VAT Directive). A credit note, which amends an invoice, is not checked, nor is a prepayment invoice, which precedes the supply (§ 14 Abs. 5 UStG asks for the date of the payment only if it is known).

The default `references` and every [preset](./api-reference/invoice/references.md#preset-packages) print both. A detail counts as shown in a reference sign of any title (e.g. `references.seller-vat-id()`, `references.service-time()` or `("Lieferdatum", "01.09.2026")`), in the name and address lines or the `extra` of the sender or the recipient, in the text of the invoice (e.g. `#info.sender.vat-id`) and, for the date of the supply, with the dates of the items. Identifiers are compared without spaces, and the date of the supply as the XML states it, in the date format of the locale: a sentence such as "Leistungsdatum entspricht Rechnungsdatum" is not recognized, so print the date with `references.service-time()`. The invoice date does not count as the date of the supply.

`invoice-pro` knows what the page shows only for a theme that says what it prints (`prints`, see [What the Theme Prints](./api-reference/theme.md#what-the-theme-prints)): the DIN-5008 theme prints the reference signs and the `extra` of the parties. The blank theme and themes without `prints` are not checked, and neither is `IP-PRINT-03` with a `header` or `footer` of the theme, which may show the tax number. A page header or footer of your own (`set page(header: ..)`) cannot be read: give company details such as the tax number as the `footer` of the theme instead, e.g. `themes.DIN-5008(footer: ..)`.

```typst
#import "@preview/invoice-pro:0.4.2": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  zugferd: "en16931",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
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
  ),
  invoice-nr: "INV-2026-103",
  date: datetime(year: 2026, month: 7, day: 8),
  service-period: datetime(year: 2026, month: 7, day: 2),
  references: (
    references.invoice-nr(),
    references.invoice-date(),
    references.service-time(), // the date of the supply: 02.07.2026
    references.seller-vat-id(), // or references.seller-tax-nr()
  ),
)

#line-items[
  #item([On-site Workshop], quantity: 8, unit: unit.hour, price: 120.00)
]

#payment-goal(days: 14)

#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
```

---

## Data Requirements for Compliance

For the generated XML payload to be valid, your input data must satisfy strict standard requirements:

### 1. Party Information

Both the `sender` and `recipient` dictionaries must include:

- **Name:** A `name` given as several lines is written as one name (BT-27, BT-44), its lines joined with `, ` as in the inline sender line: `("Kunde GmbH", "z. Hd. Frau Müller")` becomes `Kunde GmbH, z. Hd. Frau Müller`. Put a line that is not part of the name, such as an attention line, into `address` instead.
- **Country:** A country of the `country` module (e.g., `country.de`, `country.fr`, `country.us`), an ISO 3166-1 alpha-2 code (e.g., `"FR"`) or a country created with `country.custom(code: "NO", name: "Norge")`. Without `country`, the party is in the country of the locale region, and a `delivery-address` is in the recipient's country. If the VAT identifier of a party without `country` was issued by another country, the default is most likely wrong, and the e-invoice stops with `IP-COUNTRY-01`; an explicit `country` settles it, also for a foreign VAT registration. See the [Country API](./api-reference/invoice/country.md) documentation for details.
- **Address:** ZUGFeRD supports up to three distinct address lines (`ram:LineOne`, `ram:LineTwo`, and `ram:LineThree`). You can specify the address in any of the following polymorphic forms, which are fully supported:
  - **A single string or content:** Maps entirely to `ram:LineOne` (e.g., `"123 Main St"`).
  - **An array of strings or content:** Maps sequentially to the three lines. If there are more than three elements in the array, the remaining elements are joined automatically into `ram:LineThree` using a comma separator (e.g., `("123 Main St", "Suite 100", "4th Floor", "Room 402")` maps to `"123 Main St"`, `"Suite 100"`, and `"4th Floor, Room 402"` respectively).
- **City and Postal Code:** Must be fully specified. To ensure correct splitting for XML generation, you can provide this in one of two ways:
  - **As a String (Parsed Automatically):** Pass the city and postal code as a single string (e.g., `"10115 Berlin"`, `"1012 AB Amsterdam"`) or as content (e.g., `[#plz #ort]`). The post code is recognized in the format of the party's `country` (see [Predefined Countries](./api-reference/invoice/country.md#predefined-countries)). A post code of another format is not taken apart, so check the `country` of the party: a city line with a number of three or more digits and no recognized post code stops the e-invoice (`IP-ADDR-01`), as the post code would be missing from the XML. District numbers such as `"Praha 1"` or `"Dublin 2"` are fine. For a country that is not predefined, `country.custom(code: .., post-code: ..)` sets the format of its post codes (e.g. `post-code: "999-9999"` for Japan).
  - **As a Dictionary (Explicit Definition):** Alternatively, explicitly define the name and post-code using a dictionary to prevent any parsing ambiguity. The post code must be a string, so that leading zeros are kept:
    ```typst
    city: (name: "Berlin", post-code: "10115")
    ```
- **Tax Identifiers:**
  - The **sender** should include a `tax-nr` (national tax number) and/or `vat-id` (value-added tax identifier, written with its country prefix, e.g. `"DE123456789"`; spaces and invisible characters, such as the zero width spaces of copied text, are removed). The law requires one of them on the printed invoice (§ 14 Abs. 4 Satz 1 Nr. 2 UStG; Art. 226 No. 3 of the VAT Directive requires the VAT identifier): the default `references` and every [preset](./api-reference/invoice/references.md#preset-packages) print the seller's tax number and VAT identifier and the buyer's VAT identifier, with net and gross prices alike. Earlier versions printed none of them for gross prices (`tax-mode: "inclusive"`).
  - The **recipient** (buyer) should include a `vat-id` if applicable. Intra-community supplies (`K`) require it. Reverse charge (`AE`) requires it or, for a buyer without VAT identifier (e.g. a domestic reverse charge under § 13b UStG), the buyer's `legal-id` (BT-47, see below). A cross-border reverse charge needs the VAT identifier by law (Art. 226 No. 4 of the VAT Directive), which the legal registration identifier does not replace (`IP-VAT-226`). In `"basic-wl"`, which has no invoice lines, `invoice-pro` requires it for `K` and a cross-border `AE` by law (`IP-VAT-226`), but not for a domestic reverse charge.
  - The `"minimum"` profile identifies the seller by its VAT identifier (BT-31) or its legal registration identifier (BT-30), so the **sender** needs a `vat-id` or a `legal-id` there, e.g. a French micro-entrepreneur without VAT identifier its SIRET (`legal-id: id.siret(..)`). Senders identified by a `tax-nr` or `id` only need `"basic-wl"` or higher.

- **Seller Identifier (BT-29):** The buyer must be able to identify the seller (BR-CO-26), by the VAT identifier, the legal registration identifier or a seller identifier. Without any of them, the `tax-nr` is used as seller identifier. To state a different identifier, e.g. your supplier number at the customer, set `id` on the sender; it does not assert a tax registration. A globally registered identifier (e.g. a GLN) can be given with its ISO/IEC 6523 scheme, most easily with the [`id` module](./api-reference/invoice/identifiers.md):

  ```typst
  sender: (
    ...
    id: "70025",
    global-id: id.gln("4000001123452"), // or: (scheme: "0088", id: "4000001123452")
  )
  ```

  `id` accepts a scheme as well (`id: (scheme: "0088", id: ..)` is the same as `global-id`), and a `global-id` without scheme is an ordinary identifier. Only one identifier without scheme and one with scheme can be written, so a `global-id` without scheme next to `id` stops the e-invoice (`IP-ID-02`) instead of being dropped.

  The same keys on the `recipient` set the buyer identifier (BT-46), and on the `delivery-address` the deliver-to location identifier (BT-71, `id` or `location-id`). The buyer and the delivery address take only one of them, `id` or `global-id` (CII-SR-450, CII-SR-449, from the `"basic"` profile on).

- **Legal Registration Identifier (BT-30, BT-47):** The number of a party in an official register, e.g. the SIREN or SIRET of a French company, the German Handelsregister number or the Swiss UID, is its `legal-id`, on the `sender` and on the `recipient`. Every profile states it, MINIMUM included. Give it as text, which is stated without a scheme, or with a constructor of the [`id` module](./api-reference/invoice/identifiers.md), which states the ISO/IEC 6523 scheme and checks the check digit:

  | Identifier                | Input                                                             | Stated as                                  |
  | :------------------------ | :---------------------------------------------------------------- | :----------------------------------------- |
  | SIREN (France)            | `legal-id: id.siren("123 456 782")`                               | `123456782`, scheme `0002`                 |
  | SIRET (France)            | `legal-id: id.siret("123 456 782 00010")`                         | `12345678200010`, scheme `0009`            |
  | UID (Switzerland)         | `legal-id: id.uid-ch("CHE-123.456.788")`                          | `CHE123456788`, scheme `0183`              |
  | Handelsregister (Germany) | `legal-id: id.register("HRB 4711", court: "Amtsgericht München")` | `Amtsgericht München, HRB 4711`, no scheme |
  | Another register          | `legal-id: id.custom("0208", "0123456749")`                       | `0123456749`, scheme `0208`                |
  | GLN (a location, as `id`) | `global-id: id.gln("4000001123452")`                              | `4000001123452`, scheme `0088` (BT-29)     |

  A wrong check digit stops the e-invoice (`IP-ID-01`); `id.custom` takes an identifier unchecked. An identifier given for a field it does not belong to, such as a GLN as `legal-id` or a register number as `id`, stops it as well (`IP-ID-03`). The scheme of a legal registration identifier must be an ISO/IEC 6523 code (`BR-CL-11`). An identifier that produces no text, such as `legal-id: id.siret` without calling the constructor or `legal-id: (scheme: "0002")` without `id`, stops the compilation with the field, also without e-invoice; earlier versions left it out without notice.

- **Trading Name and Legal Information (BT-28, BT-45, BT-33):** `trading-name` on the `sender` or `recipient` is the name the party trades under, besides its legal `name`. `legal-info` on the `sender` is additional legal information about the seller, such as its managing directors, its registered office or its share capital (e.g. `"SAS au capital de 10 000 €, RCS Paris 123 456 782"`). The seller's trading name is stated from the `"basic-wl"` profile on, the buyer's trading name and the legal information in `"en16931"` and `"xrechnung"`; a profile that cannot state an input reports it as a warning (`IP-PROFILE-01`).

  The built-in themes print none of these details: where the law requires them on the invoice, print them from the same value, e.g. in `extra` (see [Printing identifiers](./api-reference/invoice/identifiers.md#printing-identifiers)).

- **Keys:** A key of `sender`, `recipient` or `delivery-address` that `invoice-pro` does not know is not written into the e-invoice, which is reported as a warning (`IP-KEY-01`). A key that looks like a misspelling or another name of a key the e-invoice reads, such as `vatId`, `vat_id`, `ustid`, `uid`, `e-mail`, `legal_id`, `siret` or `handelsregister` (the last two stand for `legal-id`), stops the e-invoice (`IP-KEY-02`), as its value would be missing without notice. Earlier versions accepted `siret` and `siren` with a warning, as the e-invoice had no field for them; give them as `legal-id: id.siret(..)` now. So does a post code key such as `zip` or `plz` while the `city` line has no post code: the post code belongs in `city`. Keys that invoices often carry, such as `fax-nr`, are not taken for misspellings.

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

- **Buyer Contact (BG-9):** The `contact` of the `recipient` (or its keys `contact-name` and `phone`) is written as the buyer contact in `"en16931"` and `"xrechnung"`, with the same keys as the seller contact. An `email` of the recipient alone is not a contact point: it is where the invoice goes, the electronic address (see below). Earlier versions left the buyer contact out of the e-invoice. The built-in themes do not print it; to show it on the printed invoice, print it from the same value, e.g. in `extra` of the recipient, which the DIN 5008 theme prints in the annotation zone of the address field.

- **Buyer Reference / Leitweg-ID (BT-10):** A buyer reference (such as the customer's Leitweg-ID for public sectors) is mandatory under XRechnung. Define this under `buyer-reference` or `leitweg-id` in the `recipient` dictionary. A Leitweg-ID given with `id.leitweg(..)` is checked for its check digits (`IP-ID-01`), and can be the electronic address of the buyer as well (scheme `0204`), which the report suggests for a buyer with a Leitweg-ID but without electronic address (`PEPPOL-EN16931-R010`):

  ```typst
  recipient: (
    ...
    buyer-reference: "DE123456789-12345-12"
    // or, for a public buyer reached by its Leitweg-ID:
    // leitweg-id: id.leitweg("04011000-1234512345-06"),
    // electronic-address: id.leitweg("04011000-1234512345-06"),
  )
  ```

- **Seller Tax Representative (BG-11):** A seller that is registered for VAT through a fiscal representative, e.g. a company from outside the EU, names it as `tax-representative` on the `sender`, with its name, address and VAT identifier:

  ```typst
  sender: (
    name: "Alpen Maschinen AG",
    ...
    country: country.ch,
    legal-id: id.uid-ch("CHE-123.456.788"),
    tax-representative: (
      name: "Fiskalvertretung Muster GmbH",
      address: "Steuerweg 3",
      city: "60311 Frankfurt am Main",
      country: country.de,
      vat-id: "DE987654328",
    ),
  )
  ```

  The representative's VAT identifier (BT-63) satisfies the rules that ask for a seller VAT identifier, e.g. for standard rated items (`BR-S-02`) or an intra-community supply (`BR-IC-02`): never give it as the seller's own `vat-id`. It does not identify the seller, so the seller still needs its `id`, `legal-id` or `vat-id` (`BR-CO-26`). The representative needs a name (`BR-18`), a VAT identifier (`BR-56`) and an address, which the law requires on the invoice (`IP-VAT-226`, Art. 226 No. 15 of the VAT Directive). An invoice not subject to VAT (`O`) states no VAT identifiers, so it cannot name a tax representative (`BR-O-02`). The profiles from `"basic-wl"` on state it; the built-in themes do not print it, so state it on the printed invoice as well, e.g. in its text.

- **Payee (BG-10):** When someone other than the seller receives the payment, e.g. a factoring company, name it with `payee` on the invoice (from the `"basic-wl"` profile on):

  ```typst
  #show: invoice.with(
    ...
    payee: (
      name: "Factoring Bank AG",
      global-id: id.gln("4000001543212"),                  // or `id`: BT-60
      legal-id: id.register("HRB 12345", court: "Amtsgericht Frankfurt am Main"), // BT-61
    ),
  )
  ```

  A payee needs its name, which is not the seller's (`BR-17`), and at most one of `id` and `global-id` (`CII-SR-451`). Leave out `payee` when the seller receives the payment itself. The printed invoice names the payee as the e-invoice does: the default `references` and every preset print it ("Zahlungsempfänger", "Payee", `references.payee()`), and it is the default account holder of the [`bank-details`](./api-reference/components.md#bank-details), whom the EPC-QR code names as the beneficiary, except on a credit note, which refunds the buyer. The account name of the e-invoice (BT-85) is only written for a `name` given to `bank-details`. Earlier versions printed neither, and the bank details and the EPC-QR code named the seller as the account holder.

- **Electronic Addresses & EAS Routing (BT-34 / BT-49):** For routing across networks (such as Peppol), both parties need an electronic address. XRechnung requires them; for the other profiles a missing address is reported as a warning (`"en16931"`) or not at all.
  - **Auto-derivation from VAT ID:** If `vat-id` is specified on the party, the system derives the endpoint from it. The Electronic Address Scheme (EAS) is chosen by the country prefix of the VAT ID:

    | VAT ID prefix | Scheme | VAT ID prefix | Scheme | VAT ID prefix | Scheme |
    | :------------ | :----- | :------------ | :----- | :------------ | :----- |
    | `AT`          | `9914` | `EL` / `GR`   | `9933` | `LU`          | `9938` |
    | `BE`          | `9925` | `ES`          | `9920` | `LV`          | `9939` |
    | `BG`          | `9926` | `FI`          | `0213` | `MT`          | `9943` |
    | `CH`          | `9927` | `FR`          | `9957` | `NL`          | `9944` |
    | `CY`          | `9928` | `GB`          | `9932` | `PL`          | `9945` |
    | `CZ`          | `9929` | `HR`          | `9934` | `PT`          | `9946` |
    | `DE`          | `9930` | `HU`          | `9910` | `RO`          | `9947` |
    | `EE`          | `9931` | `IE`          | `9935` | `SI`          | `9949` |
    |               |        | `IT`          | `0211` | `SK`          | `9950` |
    |               |        | `LT`          | `9937` |               |        |

    The endpoint is derived from the VAT ID on invoices not subject to VAT (category `O`) as well: they leave out the VAT identifiers themselves (BR-O-02), but the electronic address is no VAT identifier.

  - **Email Fallback:** Without a VAT ID, or with a VAT ID whose prefix is not in the table (e.g. a Danish `DK` or Swedish `SE` VAT ID, for which the EAS code list has no scheme), the email address (`contact.email` or `email`) is used with the scheme `EM`. The scheme always follows the VAT ID prefix, never the country of the address.
  - **Manual Override:** You can manually specify a custom electronic address on the party dictionary. A plain email address is accepted as well:
    ```typst
    sender: (
      ...
      electronic-address: (scheme: "0088", id: "4000001123452") // GLN Example
      // or: electronic-address: "invoices@example.com"
    )
    ```
    An address without identifier, such as `""` (e.g. an empty field of imported data), `auto` or a dictionary without `id`, counts as not given: the address is derived as described above. An address without scheme must be an email address; any other identifier needs its scheme, otherwise the e-invoice stops (BR-62 for the sender, BR-63 for the recipient). The scheme must be in the EAS code list of every official validator (BR-CL-25): a scheme the list has withdrawn, such as `9901`, stops the e-invoice, and so does one that only its newest version has, such as `0240`.

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
- **Automatic Mapping:** A string that is exactly a unit code (e.g. `"H87"`) is used as is. Other strings are mapped by the unit names of every language of `invoice-pro`, the symbols of the `unit` module and common abbreviations, e.g. `"Std."` or `"hrs"` for hours, `"Tage"` for days, `"m²"` or `"qm"` for square metres, `"km"`, `"t"`, `"kWh"`, `"Stk."` for pieces, `"Seiten"` for pages or `"pauschal"` for a lump sum. A string `invoice-pro` does not know is an error (BR-CL-23) rather than a guess: pass the unit as a dictionary with its code, e.g. `(display: "Nacht", code: "C62")` for a number of nights. A code that is also a common German abbreviation of another unit (`"STK"` is the code of sticks, `"PAL"` of pascal; also `"FL"`, `"GL"` and `"KT"`) is taken as a code, with a warning (`IP-UNIT-01`).

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

Quantities and base quantities are rounded to 4 decimals, the precision the built-in number formats print, before anything is calculated with them. A quantity of `1/3` is therefore printed and written as 0.3333, and with a price of 1000.00 the line total is 333.30, as a reader of the invoice would calculate it. If you print numbers with a custom `format.number`, keep at least 4 decimals so the printed quantity is the one the total is based on.

### 3. Tax Category Codes

Every tax rate must be mapped to a valid **UNTDID 5305** category code. Use the standard functions from the `tax` module:

- Standard VAT/GST: `tax.vat(19%)` (maps to category **S**). Reduced rates are standard rated as well, e.g. `tax.vat(7%)`.
- Zero Rated: `tax.zero()` (maps to category **Z**).
- Tax Exempt: `tax.exempt(grounds: ..)` (maps to category **E**). The `grounds` are mandatory for exempt items (BR-E-10).
- Reverse Charge: `tax.reverse-charge()` (maps to category **AE**). Requires the VAT identifier of the buyer or, for a domestic reverse charge to a buyer without one (e.g. under § 13b UStG), its legal registration identifier (`legal-id` of the recipient). A cross-border reverse charge requires the VAT identifier (`IP-VAT-226`).
- Intra-community Supply: `tax.intra-community()` (maps to category **K**). Requires the VAT identifiers of both parties. Without a `delivery-address`, the buyer's country is stated as deliver-to country; a `delivery-address` without its own `country` is in the buyer's country as well. A deliver-to country that is the seller's own country, or for a seller without VAT identifier of its own the country of its tax representative (`BR-IC-12`), or a buyer VAT identifier not issued by an EU member state (`IP-VAT-138`), is reported as a warning.
- Export: `tax.export()` (maps to category **G**). Requires the seller VAT identifier.
- Outside Scope: `tax.outside-scope()` (maps to category **O**). An invoice not subject to VAT carries no VAT identifiers, so the seller is identified by `tax-nr`, `id` or `legal-id`. Items of category `O` cannot be mixed with other categories on one invoice.
- Small Business: `tax-exempt-small-biz: true` uses the small business scheme of the locale's region, category **E** in Germany, Austria, France and Spain and **O** in Italy and Switzerland (see [Small Business Exemption](#small-business-exemption)).

EN 16931 only knows the categories `S`, `Z`, `E`, `AE`, `K`, `G`, `O`, `L` and `M`. The special constructors in `tax.special` that map to other categories (e.g. `lower-rate`, the margin schemes or split payment `B`) cannot be used for e-invoices. Items under a margin scheme are written as exempt with the note the law requires, e.g. `tax.exempt(grounds: "Margin scheme - second-hand goods")` (in Germany "Gebrauchtgegenstände/Sonderregelung"). `tax.special.ceuta-melilla(..)` (`M`) needs a rate above 0%, and items not subject to VAT (`O`) have none.

Where EN 16931 requires an exemption reason (`AE`, `K`, `G`, `O`) and the items give no `grounds` of their own, the note of the invoice language (`tax-exemption` in the [language schema](./api-reference/locale/base.md#tax-exemption), e.g. "Steuerfreie innergemeinschaftliche Lieferung" for `tax.intra-community()` in German) is printed below the line items and written as exemption reason, so the invoice and the XML state the same note. With `tax-exempt-small-biz: true`, the small business note of the invoice is the exemption reason. For the taxed categories (`S`, `Z`, `L`, `M`), `grounds` are printed on the invoice but left out of the XML, which does not allow them there. If the items of one category have different `grounds`, each of them is printed, and the XML joins them with `; ` into the one exemption reason (BT-120) of the category.

**Exemption reason code (BT-121).** Next to the text, the XML states the VAT exemption reason code of the CEF VATEX code list, from the `"basic-wl"` profile on: `VATEX-EU-AE` for a reverse charge, `VATEX-EU-IC` for an intra-community supply, `VATEX-EU-G` for an export, `VATEX-EU-O` for items not subject to VAT, and `VATEX-FR-FRANCHISE` for the small business scheme of France. The code of an exemption depends on its legal basis, so state it with `code`; without one, only the text is stated, which EN 16931 accepts (`BR-E-10`):

```typst
#item(
  [Physiotherapie],
  price: 80,
  tax: tax.exempt(
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
    code: "VATEX-EU-132-1C", // Art. 132 (1) (c) of the VAT Directive
  ),
)
```

The code must be one of the VATEX list the Factur-X and EN 16931 validators apply (`BR-CL-22`; the newer list of the KoSIT validator knows a few more, e.g. `VATEX-EU-144`, which Mustang rejects), in upper or lower case, and fit the category (`IP-TAX-02`): `VATEX-EU-AE`, `VATEX-EU-IC`, `VATEX-EU-G` and `VATEX-EU-O` belong to their categories, every other code to an exemption (`E`), and the taxed categories (`S`, `Z`, `L`, `M`) have none. An exemption with a code needs its `grounds` as well, which the printed invoice states (`IP-TAX-04`). EN 16931 states one code per VAT category and rate, so items of one group with different codes are stated with their grounds only (`IP-TAX-03`, a warning). Earlier versions stated no code at all.

`tax: none` on the invoice is not a tax category: the items are printed with 0%, but an e-invoice must say why no VAT is charged, so it stops with the error `IP-TAX-01`. Choose one of the functions above instead.

Document level discounts and surcharges (BG-20, BG-21) belong to a VAT category as well. An absolute amount is split over the categories of the items (see [VAT categories of modifiers](./api-reference/line-items/index.md#vat-categories-of-document-and-bundle-modifiers)); pin it to one with `tax`, e.g. `surcharge([Shipping], amount: 4.90, tax: tax.vat(19%))`.

Avoid using raw percentages (e.g., `19%`) directly on items if you need strict validation, as using the `tax` module functions guarantees the category codes are assigned correctly.

#### Small Business Exemption

With `tax-exempt-small-biz: true`, all items and pinned modifiers use the small business scheme of the locale's region. Its legal note is printed below the line items, and the XML states the same text as exemption reason (BT-120):

| Region | Category | Legal note (printed and BT-120)                                                                  |
| :----- | :------- | :----------------------------------------------------------------------------------------------- |
| DE     | `E`      | Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gemäß § 19 Abs. 1 UStG.                   |
| AT     | `E`      | Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gem. § 6 Abs. 1 Z 27 UStG.                |
| FR     | `E`      | TVA non applicable, art. 293 B du CGI.                                                           |
| ES     | `E`      | Exento de IVA según el régimen especial de franquicia para pequeñas empresas.                    |
| IT     | `O`      | Operazione in franchigia da IVA ai sensi dell'art. 1, commi da 54 a 89, della Legge n. 190/2014. |
| CH     | `O`      | Nicht MWST-pflichtig / Non soumis à la TVA / Non assoggettato all'IVA                            |

If the language of the invoice differs from the region (e.g. `locale.en-de`), a translated note comes first and the legal note follows in parentheses. The note is printed below the line items, as it is mandatory on the invoice (e.g. § 34a UStDV in Germany), also with `line-items(show-information: false)`, which hides only the information about the items (such as the tax rate or the unit they share). Earlier versions hid the exemption notes and the `notes` of the invoice with it, while the XML stated them.

- **Exempt (`E`), in Germany, Austria, France and Spain:** the scheme exempts the turnover of small businesses. In Germany, § 19 Abs. 1 UStG declares it tax exempt ("steuerfrei") since 2025 (Jahressteuergesetz 2024), and the invoice must note that the small business exemption applies (§ 34a UStDV). The Spanish note refers to the franchise of the EU small business scheme (Directive (EU) 2020/285) and cites no provision of Spanish law; where one applies, state it with an override (see below). An exempt invoice needs the seller's VAT identifier or tax number (BR-E-02): set `tax-nr` (e.g. the Steuernummer) or `vat-id` on the sender. Both are written to the XML, and the buyer's electronic address is derived from its VAT identifier as on any other invoice. A French micro-entrepreneur without an intra-community VAT number can state its SIREN as `tax-nr`, which is written as the seller's tax registration (BT-32).
- **Not subject to VAT (`O`), in Italy and Switzerland:** supplies under the Italian _regime forfettario_ are not subject to VAT, and Swiss businesses below the turnover threshold are not liable for VAT. As with `tax.outside-scope()`, the XML carries no VAT identifiers (BR-O-02), and the seller is identified by `tax-nr` or `id`.

:::warning Breaking change of the XML
Earlier versions wrote the small business exemption of every region as category `O` ("not subject to VAT") and left out the VAT identifiers. Invoices with `tax-exempt-small-biz: true` in the regions DE, AT, FR and ES are now written as category `E` and keep the VAT identifiers of seller and buyer, from which the electronic addresses (BT-34, BT-49) are derived, and the German note follows the wording of the amended § 19 UStG. A sender with neither `tax-nr` nor `vat-id` (only an `id`) is now reported as BR-E-02. German-language invoices of other regions (e.g. `locale.de-at`) no longer cite the German § 19 UStG in front of the region's note.
:::

To state another note or category, override the scheme of the region, e.g. `locale: locale.de-de.with(locale.custom.tax(small-enterprise-special-scheme: tax.exempt(grounds: "...")))`.

### 4. Gross Prices

With `tax-mode: "inclusive"`, the invoice prints gross prices, while the XML states net amounts as EN 16931 requires. The net unit prices are rounded with the fine precision of the locale (`normalize.money-fine`), like every unit price. Every line and allowance is converted on its own, and rounding differences of a cent are assigned to the largest line of the VAT category, so the XML adds up exactly to the net and gross totals printed on the invoice.

### 5. Payment Terms and Instructions

- **Due Date or Payment Terms (BT-9 / BT-20):** As long as an amount is due, the invoice must state when to pay (BR-CO-25). Add a [`payment-goal`](./api-reference/components.md#payment-goal) (with `days` or a `date`) or set `due-date` on the invoice. A textual `date` or `due-date` (e.g. `[upon receipt]`) is written as payment terms, with its line breaks. An invoice that is [paid already](#paid-invoices) has nothing due and needs neither.
- **Payment Instructions (BG-16):** The components that say how the buyer pays are the payment means of the e-invoice (see below). IBAN and BIC are written without spaces and in upper case; they are the same values the bank details print and the EPC-QR code carries.

#### Payment Means

Each payment means has a component that prints it and states it in the e-invoice, so the printed invoice and the XML always say the same. The payment goal prints the sentence of the payment means: it asks for a transfer only when the buyer pays by credit transfer.

| Component                                                    | Payment means code (BT-81)                                       | Written details                                                                                                  |
| :----------------------------------------------------------- | :--------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| [`bank-details`](./api-reference/components.md#bank-details) | `58` SEPA credit transfer (`30` in another currency than euro)   | IBAN (BT-84), account name (BT-85, only a `name` given to `bank-details`), BIC (BT-86)                           |
| [`direct-debit`](./api-reference/components.md#direct-debit) | `59` SEPA direct debit (`49` in another currency than euro)      | Mandate reference (BT-89), creditor identifier (BT-90), debited account (BT-91)                                  |
| [`card-payment`](./api-reference/components.md#card-payment) | `54` credit card, `55` debit card, `48` bank card (`kind: auto`) | Last digits of the card number (BT-87), card holder (BT-88)                                                      |
| [`paid`](./api-reference/components.md#paid)                 | The code of its `method`, e.g. `10` for cash                     | Paid amount (BT-113) equal to the total, nothing due (BT-115), and the printed sentence as payment terms (BT-20) |

- **One payment means:** An invoice states one payment means (BT-81), so that the buyer knows how to pay and does not pay twice. A direct debit next to bank details is an error in XRechnung (`BR-DE-23-b`), as is a direct debit next to a payment card (`BR-DE-24-b`); `invoice-pro` reports the other combinations as `IP-PAY-03`. To show your bank account for information only, print it as text. Several `bank-details` are several accounts of one credit transfer, and each of them is written.
- **EPC-QR code:** The QR code of the bank details asks the buyer to transfer the amount. It is therefore only shown by default when the invoice is paid by credit transfer: not next to a `direct-debit` or a `card-payment`, and not on a `paid` invoice. `qr-code: (display: true)` shows it anyway.
- **XRechnung:** An XRechnung requires payment instructions (`BR-DE-1`) and the details of its payment means: the IBAN of a credit transfer (`BR-DE-23-a`), the payment card of a card payment (`BR-DE-24-a`), and for a direct debit the mandate reference (`PEPPOL-EN16931-R061`), the creditor identifier (`BR-DE-30`) and the debited account (`BR-DE-31`). The IBANs must be valid (`BR-DE-19`, `BR-DE-20`); `invoice-pro` checks the check digits of the creditor identifier as well (`IP-PAY-02`). XRechnung only warns about an invalid IBAN and about a missing mandate reference, and the KoSIT validator accepts such an invoice, but other validators, such as Mustang, reject it, and the amount could not be paid or collected. `invoice-pro` therefore reports these rules as errors.
- **Profiles:** BASIC WL and BASIC state a direct debit, but neither the account name nor the payment card, and MINIMUM states no payment means at all, only the amount due. What a profile cannot state is still printed, and the report lists it as the warning `IP-PROFILE-01`.

#### Direct Debit

A SEPA direct debit needs the mandate the buyer signed and your creditor identifier; XRechnung requires the IBAN of the debited account as well. The payment goal then announces the debit instead of asking for a transfer:

```typst
#import "@preview/invoice-pro:0.4.2": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.en-de,
  zugferd: "xrechnung",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
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
    email: "invoices@acme.example",
    buyer-reference: "04011000-12345-67",
  ),
  invoice-nr: "INV-2026-104",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Maintenance contract, September], price: 250)
]

// "The total amount of 297,50 € will be collected from your account by
// direct debit within 14 days."
#payment-goal(days: 14)

#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
```

#### Paid Invoices

An invoice that is paid already, e.g. in cash or by card at the counter, uses [`paid`](./api-reference/components.md#paid) instead of a payment goal: it prints that the amount was paid, and how, and that nothing is due. The e-invoice states the total as paid amount (BT-113), nothing due (BT-115) and the payment means it was paid with. `method` is one of `"cash"` (10), `"cheque"` (20), `"online"` (68), `"card"` (48, or the code of the `card-payment`), `"transfer"` (58, or 30 in another currency than euro) and `"direct-debit"` (59, or 49), or another code of UNTDID 4461 with its printed name, e.g. `(code: "97", name: [Clearing])`.

```typst
#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
```

A card payment or a direct debit adds its details with its own component. XRechnung requires them: the payment card for `"card"` (`BR-DE-24-a`), the direct debit for `"direct-debit"` (`BR-DE-25-a`, in another currency than euro its mandate reference, `PEPPOL-EN16931-R061`) and the bank details for `"transfer"` (`BR-DE-23-a`). The other profiles with payment means ask for the bank details of `"transfer"` as well, as EN 16931 requires the account of a credit transfer (`BR-61`), although its official validation does not check it in CII:

```typst
#paid(method: "card")
#card-payment(last4: "4242", holder: "Claire Martin", kind: "credit")
```

With prepayments, the printed sentence states the remaining amount that was paid; the e-invoice states the total as paid amount either way. An invoice that is paid has no payment goal and no payment terms: `paid` next to `payment-goal`, or next to a text as `due-date` of the invoice, which would be the payment terms (BT-20) instead of the sentence that it is paid, stops the compilation. A `datetime` as `due-date` is the due date (BT-9) the payment met.

A payment means code of its own must be the code of the component that details its kind, as the invoice states one (BT-81): `paid(method: (code: "54", name: [Visa]))` next to `card-payment(kind: "credit")` states 54 with the card details and prints its name, but next to `card-payment()` (48, a card of any kind) it stops the compilation, as one of the codes would be lost.

On a credit note or a self-billed invoice, the sender paid the amount to the recipient: the sentence says so (e.g. "Den Betrag in Höhe von 119,00 € haben wir Ihnen am 01.09.2026 ausgezahlt."), and the e-invoice states it as payment terms (BT-20).

#### Cash Discount (Skonto)

A cash discount for a payment within fewer days is part of the payment goal. One entry is printed after the payment sentence and written into the payment terms (BT-20):

```typst
// "... within 30 days ... For payment within 14 days, a cash discount of 2%
// is granted."
#payment-goal(days: 30, discount: (days: 14, percent: 2%))
```

An array states several steps, and `basis` the amount a discount applies to, e.g. `discount: ((days: 7, percent: 3%), (days: 14, percent: 2%, basis: 1000))`. XRechnung states each step as a line in the syntax of the KoSIT (`BR-DE-18`), e.g. `#SKONTO#TAGE=14#PROZENT=2.00#`, with `#BASISBETRAG=` for the basis; the other profiles state the printed sentences. The percentage has at most two decimals, as the e-invoice states it. A cash discount changes no amount of the invoice: the buyer deducts it when paying in time. It is therefore no [`discount`](./api-reference/line-items/index.md#adjustments-modifier-discount--surcharge), which reduces the amounts of the invoice no matter when the buyer pays.

If you write the payment terms yourself, as a textual `due-date`, state a cash discount in XRechnung as a line of its own in this syntax: `#SKONTO#TAGE=` with the days, `#PROZENT=` with the percent and two decimals, optionally `#BASISBETRAG=` with the amount it applies to, and a closing `#`. In the `"xrechnung"` profile, every line of the payment terms that starts with `#` must follow this syntax, and a line after the last cash discount that contains `#` more than once must end with its last `#` (BR-DE-18). `invoice-pro` adds the line break that XRechnung requires after a closing `#` at the end of the terms:

```typst
due-date: "Zahlbar innerhalb von 30 Tagen netto, innerhalb von 14 Tagen mit 2 % Skonto.\n#SKONTO#TAGE=14#PROZENT=2.00#",
```

The themes do not print a textual `due-date` on their own: print it where you state the payment terms (e.g. with [`#info.due-date`](./api-reference/components.md#info-module)), so that the printed invoice states the cash discount as well.

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

`order-nr` (BT-13), `contract-nr` (BT-12), `delivery-note-nr` (BT-16) and `preceding-invoice-nr` (BT-25, e.g. for corrections) are written to the XML where the profile supports them. `project` is written as the project reference (BT-11), which public buyers often require, in the `"en16931"` and `"xrechnung"` profiles; the other profiles have none, which is reported as a warning (`IP-PROFILE-01`).

`preceding-invoice-date` (a `datetime`) is the date of the preceding invoice (BT-26), written next to its number from the `"basic-wl"` profile on (`"minimum"` has no preceding invoice reference, which is reported as a warning, `IP-PROFILE-01`); `references.preceding-invoice-date()` prints it. The default `references` print the number and the date of the preceding invoice if you give them. A date without `preceding-invoice-nr` cannot be written and stops the e-invoice (`BR-55`). A corrected invoice (`document-type: "corrected"`) replaces the preceding invoice, so it must name it: `BR-DE-26` in XRechnung (which KoSIT only warns about, but Mustang rejects), `IP-DOC-02` in the other profiles, as the VAT Directive (Art. 219) requires a document that amends an invoice to refer to it.

### 9. Document Type (BT-3)

`document-type` states what kind of document the invoice is. It is written as the document type code (BT-3, UNTDID 1001), and unless you set `subject`, it is the printed title:

| `document-type`       | BT-3  | Title (German / English)                 | Meaning                                                                                                 |
| :-------------------- | :---- | :--------------------------------------- | :------------------------------------------------------------------------------------------------------ |
| `auto` or `"invoice"` | `380` | Rechnung / Invoice                       | A commercial invoice: the buyer pays the seller.                                                        |
| `"credit-note"`       | `381` | Rechnungskorrektur / Credit Note         | Credits amounts to the buyer, e.g. for returned goods or a discount granted later.                      |
| `"corrected"`         | `384` | Korrigierte Rechnung / Corrected Invoice | Replaces the invoice `preceding-invoice-nr`.                                                            |
| `"prepayment"`        | `386` | Anzahlungsrechnung / Prepayment Invoice  | Asks for an advance payment, which the final invoice deducts. XRechnung does not allow it (`BR-DE-17`). |
| `"self-billed"`       | `389` | Gutschrift / Self-Billing Invoice        | Issued by the buyer for the seller, e.g. a commission statement (see below).                            |

Any other code of UNTDID 1001 for invoices and credit notes can be given as text, e.g. `"326"` for a partial invoice or `"875"` to `"877"` for construction invoices. It is printed with the title of its kind (an invoice or a credit note), so give it a `subject` of its own. XRechnung allows only `326`, `380`, `381`, `384`, `389`, `875`, `876` and `877` (`BR-DE-17`): the KoSIT validator only warns about other codes, but Mustang rejects them, so `invoice-pro` reports an error; with `zugferd: auto`, such an invoice is written as EN 16931.

**Credit notes.** EN 16931 states a credit note with **positive** amounts: the items are the credited amounts, entered with positive prices, and `document-type: "credit-note"` says that they are credited to the buyer. The amount due (BT-115) is the amount the buyer gets back.

- A credit note with a negative total would ask the buyer to pay, so it stops the e-invoice (`IP-DOC-03`). An invoice with a negative total is valid, but a credit note is the document for it (`IP-DOC-04`, a warning).
- As long as an amount is due, the credit note says when or how the buyer gets it (`BR-CO-25`): [`payment-goal`](./api-reference/components.md#payment-goal) prints that the amount is transferred within the given days (and states that date, BT-9), a textual `due-date` (e.g. `due-date: "Der Betrag wird mit Ihrer nächsten Rechnung verrechnet."`) states the terms (BT-20).
- [`bank-details`](./api-reference/components.md#bank-details) on a credit note are the account the amount is paid to, usually the buyer's: the account holder defaults to the recipient's name, and no EPC-QR code is printed. Do not reuse the bank details of your invoices on a credit note: your own account would be printed with the buyer as its holder and stated as the account the credit is paid into. XRechnung requires payment instructions (BG-16) on credit notes as well (`BR-DE-1`): the recipient's account you transfer the amount to, `paid` if it is paid already, or for a set-off against an invoice `paid(method: (code: "97", name: [Verrechnung]))`.
- The sender of a credit note or a self-billed invoice pays the amount, so it cannot collect it from the recipient: [`direct-debit`](./api-reference/components.md#direct-debit), [`card-payment`](./api-reference/components.md#card-payment) and a cash discount of the payment goal (`discount`) stop the compilation on these documents. [`paid`](./api-reference/components.md#paid) states that the amount has been paid already.
- A document that amends an invoice must refer to it (Art. 219 VAT Directive): set `preceding-invoice-nr` (and `preceding-invoice-date`) to the invoice the credit note refers to. The default `references` print them.
- The date of the supply of a credit note is the one of the supply it credits: set `service-period` to it, or give the items their `date`. The date of the credit note is not the date of the supply, so without them the credit note states none (see [Service Period](#10-service-period-bt-72--bg-14)).
- In German, a credit note is titled "Rechnungskorrektur": the German VAT law reserves "Gutschrift" for self-billed invoices (§ 14 Abs. 2 Satz 2 UStG). A commercial credit note titled "Gutschrift" is permitted as well; set `subject: "Gutschrift"` together with `document-type: "credit-note"` if you prefer it.

```typst
#import "@preview/invoice-pro:0.4.2": *

#show: invoice.with(
  zugferd: auto,
  document-type: "credit-note",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
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
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "CN-2026-007",
  date: datetime(year: 2026, month: 7, day: 20),
  preceding-invoice-nr: "INV-2026-102",
)

#line-items[
  #item([Workshop cancelled by us], quantity: 1, price: 1500.00, tax: tax.vat(19%))
]

#payment-goal(days: 14)

#bank-details(
  bank: "Acme Bank",
  iban: "DE89370400440532013000",
)
```

**Self-billed invoices.** The buyer issues a self-billed invoice for the seller, e.g. a publisher for the royalties of an author or a principal for the commissions of an agent. `sender` is then the buyer, who issues the document, and `recipient` the seller:

- The XML states the recipient as seller (BG-4) and the sender as buyer (BG-7). The messages of the e-invoice name the inputs, e.g. `recipient.vat-id` for the seller VAT identifier.
- The default references and every preset state the tax number and VAT ID of the seller (the recipient), which the law requires on the invoice, and the VAT ID of the buyer (the sender); `references.seller-tax-nr()`, `references.seller-vat-id()` and `references.buyer-vat-id()` print them in references of your own. Earlier versions printed the sender's tax identifiers with the presets.
- The payment goal says that the sender transfers the amount, and the [`bank-details`](./api-reference/components.md#bank-details) are the seller's account, without EPC-QR code.
- The title is the mention the law requires on a self-billed invoice (Art. 226 No. 10a VAT Directive): "Gutschrift" in German (§ 14 Abs. 4 Satz 1 Nr. 10 UStG), "Self-Billing Invoice" in English, "Autofacturation" in French, "Autofatturazione" in Italian and "Facturación por el destinatario" in Spanish. Keep it in a `subject` of your own.

**Titles that name another document (`IP-DOC-01`).** Without `document-type`, the e-invoice states a commercial invoice (`380`), which asks the buyer to pay. If the subject names another kind of document, the e-invoice stops with `IP-DOC-01`: a credit note ("Gutschrift", "Rechnungskorrektur", "Stornorechnung", "Credit note", "Avoir", "Nota di credito", ...), a corrected or a self-billed invoice, or a document that is no invoice at all, such as a quote ("Angebot", "Kostenvoranschlag", "Quote", "Offer", "Devis", "Preventivo", "Presupuesto"), a delivery note ("Lieferschein"), an order confirmation, a pro forma invoice or a payment reminder. Set the matching `document-type`, or `document-type: "invoice"` if it is an invoice. The first word of the subject that names a kind of document decides, so "Rechnung zum Angebot 2026-5" is an invoice. An e-invoice is only written for invoices and credit notes: do not set `zugferd` for quotes and other documents that are no invoice.

### 10. Service Period (BT-72 / BG-14)

The date or period of the supply is mandatory invoice content in many countries (e.g. § 14 Abs. 4 Nr. 6 UStG). `invoice-pro` resolves it once, for the printed invoice ([`references.service-time()`](./api-reference/invoice/references.md)) and the XML alike:

1. the `service-period` of the invoice, a `datetime` or a period `(start, end)`, if you set it;
2. else from the earliest to the latest `date` of the items (of `item`, `bundle` and `group`, a date or a period). Items without a date do not count when others have one;
3. else the invoice date, if no item has a date. Not so on a credit note (`document-type: "credit-note"`, 381), which amends an invoice, and on a prepayment invoice (`"prepayment"`, 386), which asks for an advance payment before the supply: their own date is not the date of the supply, so without a `service-period` or dates of the items, neither the printed document nor its XML states one. XRechnung recommends one (`BR-DE-TMP-32`, a warning), and an intra-community supply (K) requires one (`BR-IC-11`, an error): set `service-period` to the date or period of the supply the credit note refers to. Earlier versions stated the date of the credit note.

A single date is written as the actual delivery date (BT-72), a period as the invoicing period (BG-14, BT-73 and BT-74), both from the `"basic-wl"` profile on (`"minimum"` has neither: a `service-period` is then reported as a warning, `IP-PROFILE-01`). The default `references` print a `service-period` you set and, for a seller in Germany, the date of the supply in any case: German law requires it on the invoice also when it is the date of the invoice (§ 14 Abs. 4 Satz 1 Nr. 6 UStG), and without dates on the items, the XML states the invoice date. Every preset prints it as well; with references of your own, add `references.service-time()`:

```typst
#show: invoice.with(
  service-period: (
    datetime(year: 2026, month: 6, day: 1),
    datetime(year: 2026, month: 6, day: 30),
  ),
  references: (references.invoice-nr(), references.service-time()),
  // ...
)
```

The printed service period must be the one the XML states (`IP-PERIOD-01`). `references.service-time(value: ..)` prints a date or a period `(start, end)` given as `value` in the date format of the locale, and another date than the one the XML states is an error. A text of its own, e.g. `references.service-time(value: "Juni 2026")` or a reference `("Leistungszeitraum", "Juni 2026")`, cannot reach the XML: without dates on the items or a `service-period`, the XML states the invoice date, which the text contradicts, so it is an error; besides them, the text may name the same period in other words, so it is a warning. Set `service-period` instead, and print it with `references.service-time()`. The same holds for a credit note or a prepayment invoice without dates, whose XML states no date of the supply: a date printed with `value` is an error, a text of its own a warning. A printed invoice without the date of the supply is reported as well (`IP-PERIOD-03`, see [Printed Details](#printed-details)).

### 11. Notes (BT-22)

`notes` on the invoice are texts about the invoice as a whole, e.g. terms of delivery or legal notices. They are printed below the line items, with the exemption notes, and written into the XML as invoice notes (BT-22) with their line breaks, from the `"basic-wl"` profile on (`"minimum"` has none, which is reported as a warning, `IP-PROFILE-01`). Like the exemption notes, they are printed also with `line-items(show-information: false)`, so the printed invoice states what the XML states. A note can carry a subject code of UNTDID 4451 (BT-21, `BR-CL-08`), e.g. `"AAI"` for general information or `"REG"` for regulatory information:

```typst
#show: invoice.with(
  notes: (
    "Lieferung frei Haus.",
    (text: "Es gelten unsere Allgemeinen Geschäftsbedingungen.", subject-code: "AAI"),
  ),
  // ...
)
```

### 12. Item Notes, Periods and Country of Origin

Besides its name and description, an [`item`](./api-reference/line-items/index.md#item) can state a note, its date and the country its goods come from. They are printed with the item and written into its invoice line:

| `item` parameter                                                  | Printed                                                             | XML                                                                                  | Profiles                              |
| :---------------------------------------------------------------- | :------------------------------------------------------------------ | :----------------------------------------------------------------------------------- | :------------------------------------ |
| `note`, a text                                                    | below the description                                               | invoice line note (BT-127), with its line breaks                                     | `"basic"`, `"en16931"`, `"xrechnung"` |
| `date`, a `datetime` or a period `(start, end)`                   | as the date of the item                                             | invoice line period (BG-26, BT-134 and BT-135); a single date is a period of one day | `"basic"`, `"en16931"`, `"xrechnung"` |
| `origin`, a country (`country.it`) or an ISO 3166-1 code (`"IT"`) | below the note, e.g. "Ursprungsland: IT" or "Country of origin: IT" | item country of origin (BT-159)                                                      | `"en16931"`, `"xrechnung"`            |

`"minimum"` and `"basic-wl"` have no invoice lines. `"basic"` has no country of origin: `origin` is only printed there, which is reported as a warning (`IP-PROFILE-01`). A `bundle` is one line, printed with the names of its items, so an item inside it cannot have a `note` or an `origin` (an error); mention them in the `description` of the bundle. A country that is not in the ISO 3166-1 code list of EN 16931 (`BR-CL-15`) and a period that ends before it starts (`BR-30`) stop the e-invoice.

The dates of the items are the service period of the invoice, unless you set `service-period` (see [Service Period](#10-service-period-bt-72--bg-14)). Then the date of every item must lie within it: XRechnung requires this for an invoicing period (`PEPPOL-EN16931-R110` and `R111`, which the KoSIT validator reports as warnings and Mustang as errors, so `invoice-pro` reports an error); in the other profiles, and for a service period of a single day, a date outside it is a warning (`IP-PERIOD-02`).

```typst
#import "@preview/invoice-pro:0.4.2": *

#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
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
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
  ),
  invoice-nr: "INV-2026-118",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(
    [Espresso machine],
    price: 1290.00,
    tax: tax.vat(19%),
    date: datetime(year: 2026, month: 8, day: 3),
    note: "Serial number 4711-0815",
    origin: country.it,
  )
  #item(
    [Barista training],
    quantity: 2,
    unit: unit.day,
    price: 450.00,
    tax: tax.vat(19%),
    date: (
      datetime(year: 2026, month: 8, day: 10),
      datetime(year: 2026, month: 8, day: 11),
    ),
  )
]

#payment-goal(days: 14)

#bank-details(
  bank: "Acme Bank",
  iban: "DE89370400440532013000",
)
```

### 13. Currency (BT-5)

The invoice currency (BT-5) is the currency of the locale (`EUR`, or `CHF` for the Swiss locales), unless you set `currency` on the invoice to an ISO 4217 code. The amounts are then printed in that currency in the number format of the locale: with its symbol for `EUR` (€), `USD` ($), `GBP` (£), `JPY` (¥), `PLN` (zł), `CZK` (Kč) and `HUF` (Ft), otherwise with its code (e.g. "1.234,50 CHF" or "1.234,50 SEK"), and rounded to its decimals (e.g. none for `JPY`).

```typst
#show: invoice.with(
  locale: locale.de-de,
  currency: "USD", // prints "1.234,50 $" and states USD in the e-invoice
  // ...
)
```

The EPC-QR code of the [bank details](./api-reference/components.md#bank-details) transfers euros only, so it is shown for invoices in euro only, and a credit transfer in another currency is written as a credit transfer (BT-81 `30`) instead of a SEPA credit transfer (`58`). An e-invoice whose printed amounts show another currency than the one it states stops with `IP-PRINT-02`, e.g. with a currency formatter of a custom locale that prints "zł" while the locale states `EUR`. The profiles based on EN 16931 accept only the currencies of its code list (`BR-CL-04`). The printed invoice reads the currency code as the e-invoice states it, in upper case and without spaces: a custom locale with the code `"eur"` invoices in euro, so its bank details show the EPC-QR code, and a direct debit is a SEPA direct debit whose creditor identifier is checked. A currency with more than 2 decimals, such as `KWD`, rounds its amounts to them, which the XML cannot state (`BR-DEC-*`, reported for `currency`): create such an invoice without e-invoice, or with a locale of your own whose currency has 2 decimals, e.g. `locale.en-de.with((region: (currency: (code: "KWD", symbol: "KWD", decimals: 2))))`.

In the profiles based on EN 16931, the currency must be in the code lists of both official validators (`BR-CL-04`): a currency that is newer than the list of one of them (e.g. `VES`) stops the e-invoice, and so does one that the current list has withdrawn (e.g. `BGN` and `HRK`, replaced by the euro).

**VAT in the national currency (BT-6, BT-111).** Within the EU, an invoice in another currency must also state the VAT amount in the national currency of the member state where the supply is taxed (Art. 230 VAT Directive), e.g. in euro for a supply taxed in Germany. `invoice-pro` does not support the VAT accounting currency (BT-6) and the VAT total in it (BT-111) yet: state the VAT amount in the national currency and the exchange rate in a note (`notes`), which is printed and written into the e-invoice (BT-22).

---

## Hardcoded Details & Limitations

- **Business Process URN (BT-23):** Whenever using the `"en16931"` or `"xrechnung"` profiles, the Business Process context URN is hardcoded to `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0` (standard billing transaction).
- **EAS Scheme Fallback:** If the prefix of a party's VAT ID has no known scheme and neither a custom `electronic-address` nor an email address is specified, the electronic address block is omitted from the XML payload.
- **Plain Text:** Names, addresses and references given as content are written as their plain text; formatting is dropped.
- **Factur-X XMP Metadata:** The PDF lacks the Factur-X XMP metadata, because Typst cannot write custom XMP metadata yet. The XML is not affected (see [Factur-X XMP Metadata](#factur-x-xmp-metadata)).
- **VAT Accounting Currency (BT-6, BT-111):** Not supported. See [Currency](#13-currency-bt-5).

---

## Factur-X XMP Metadata

A Factur-X / ZUGFeRD PDF announces its XML in the XMP metadata of the PDF, with the Factur-X extension schema (`fx:DocumentType`, `fx:DocumentFileName`, `fx:Version` and `fx:ConformanceLevel`). Typst cannot write custom XMP metadata yet, so `invoice-pro` cannot add these entries. This is a limitation of the Typst platform, not of the invoice data:

- The embedded XML (`factur-x.xml`, or `xrechnung.xml` in the XRechnung profile) is complete and valid for its profile. Most receiving systems only extract and process this XML.
- Validators that check the PDF itself reject it. The Mustang validator, for example, reports `XMP Metadata: ConformanceLevel not found` together with the missing `DocumentType`, `DocumentFileName` and `Version`, and rates the PDF (not the XML) as invalid.

`invoice-pro` will write the metadata as soon as Typst supports custom XMP metadata ([typst/typst#5667](https://github.com/typst/typst/issues/5667)). It is prepared already: `src/zugferd/xmp.typ` builds the Factur-X metadata of every profile (the document type `INVOICE`, the name of the attached XML, the version `1.0` and the conformance level `MINIMUM`, `BASIC WL`, `BASIC`, `EN 16931` or `XRECHNUNG`) together with the PDF/A description of its extension schema, and a test compares it with the metadata that Mustang writes (see below). Until Typst can write it, the package does not load this module, so it costs no compile time.

:::info Optional post-processing, outside the package
You do not need any of this to create an invoice, and `invoice-pro` does not run external tools. If a recipient requires a PDF that passes the Factur-X PDF check, you can add the metadata afterwards with the [Mustang](https://www.mustangproject.org/) command line tool, which needs Java: download `Mustang-CLI-2.14.0.jar` from the [Mustang releases](https://github.com/ZUGFeRD/mustangproject/releases) and run it with `java -jar`. The steps below were tested with Mustang CLI 2.14.0.
:::

```bash
# 1. Compile the invoice as usual.
typst compile --pdf-standard=a-3b invoice.typ invoice.pdf

# 2. Extract the XML that invoice-pro embedded.
java -jar Mustang-CLI-2.14.0.jar --action extract \
  --source invoice.pdf --out invoice.xml

# 3. Embed it again together with the Factur-X XMP metadata. The profile
#    letter must match the profile of the invoice (see the table below).
java -jar Mustang-CLI-2.14.0.jar --action combine \
  --source invoice.pdf --source-xml invoice.xml --out invoice-facturx.pdf \
  --format fx --version 1 --profile E --no-additional-attachments

# 4. Check the result: PDF, XML and the summary must be "valid".
java -jar Mustang-CLI-2.14.0.jar --action validate --source invoice-facturx.pdf
```

| `zugferd` profile of the invoice | `--profile` |
| :------------------------------- | :---------- |
| `"minimum"`                      | `M`         |
| `"basic-wl"`                     | `W`         |
| `"basic"`                        | `B`         |
| `"en16931"`                      | `E`         |
| `"xrechnung"`                    | `X`         |

With `zugferd: auto`, use the profile the invoice was written in: `X` if the guideline ID of the XML (BT-24) ends in `xrechnung_3.0`, otherwise `E`. `--format fx --version 1` writes the metadata of Factur-X 1.0, which ZUGFeRD 2.1 and later use as well. For `X`, Mustang names the XML `xrechnung.xml`, as `invoice-pro` does, and replaces it with the same XML, so the PDF carries it once. XRechnung is primarily exchanged as the XML file itself: if a recipient asks for an XRechnung, you can send `invoice.xml` from step 2.

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
