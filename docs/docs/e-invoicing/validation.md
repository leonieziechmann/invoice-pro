---
sidebar_position: 2
---

# Validation and Error Reporting

Before the XML is embedded, `invoice-pro` checks the invoice data against the business rules of EN 16931, the selected Factur-X profile and, for `"xrechnung"`, the German CIUS (rules `BR-DE-*`). The check does not stop at the first problem: it collects **every** violated rule, so you can fix them all in one go.

This page describes what is checked, how the problems are reported and what you can do with them. How the XML itself is tested is described in [Testing and Conformance](./conformance.md).

## The Error Listing

By default, the compilation fails with the complete list. Each entry names the rule, the input to look at, what is wrong and how to fix it:

```text
error: assertion failed: The e-invoice (ZUGFeRD / Factur-X, profile XRechnung 3.0) is not valid: 2 errors.
  1. [BR-DE-15] recipient.buyer-reference: XRechnung requires the buyer reference (BT-10), e.g. the Leitweg-ID.
     Hint: Set `buyer-reference` (or `leitweg-id`) on the recipient.
  2. [BR-CO-25] payment-goal: An amount is due, but neither the payment due date (BT-9) nor the payment terms (BT-20) are given.
     Hint: Add `#payment-goal(days: 14)` or set `due-date` on the invoice.
Set `zugferd-errors: "report"` on the invoice to list these problems in the document instead.
```

## Errors and Warnings

Problems come in two levels:

- **Errors** make the XML invalid for the profile (e.g. a missing invoice number, an unknown unit code or a VAT breakdown that does not add up), or the invoice wrong in a way the official validators cannot see (see below).
- **Warnings** point out data that is valid but most likely not intended (e.g. an EN 16931 invoice without the electronic addresses Peppol expects, a key of a party that `invoice-pro` does not know, or a unit code that is also a common abbreviation of another unit). Warnings never stop the compilation.

For XRechnung, the seller contact phone number must contain at least three digits (`BR-DE-27`), and the email address must match the pattern of the XRechnung Schematron (`BR-DE-28`, ASCII only: write a domain with umlauts in punycode, e.g. `info@xn--mller-bau-q9a.de` for `info@müller-bau.de`). XRechnung only warns about these two rules, and the KoSIT validator accepts such an invoice, but other validators, such as Mustang, reject it. `invoice-pro` therefore reports them as errors.

## Code Lists

Codes (currencies, countries, units, schemes of identifiers and electronic addresses, payment means and VAT exemption reasons) must be in the code lists that the validation of the profile applies, and the error names the rule of the validator that rejects the code:

| Profile                   | Code lists                                                                          | Rule of an unknown code, e.g. of a currency                                   |
| :------------------------ | :---------------------------------------------------------------------------------- | :---------------------------------------------------------------------------- |
| `"minimum"`, `"basic-wl"` | the lists of Factur-X 1.0.07 alone                                                  | `FX-SCH-A-000040`                                                             |
| `"basic"`, `"en16931"`    | all of them: Factur-X 1.0.07 and both versions of the EN 16931 code lists           | `BR-CL-04`, or `FX-SCH-A-000040` for a code that only the Factur-X list lacks |
| `"xrechnung"`             | both versions of the EN 16931 code lists alone (1.3.12 in Mustang, 1.3.16 in KoSIT) | `BR-CL-04`                                                                    |

- `"xrechnung"` accepts codes that the Factur-X lists lack, such as the electronic address schemes `0219` and `0220`, the Netherlands Antilles (`AN`) or the São Tomé dobra (`STD`), and `"minimum"` and `"basic-wl"` accept South Sudan (`SS`), which the EN 16931 lists lack.
- A currency that the newest EN 16931 list has withdrawn, such as `BGN` or `HRK` (replaced by the euro), is allowed wherever the Factur-X validation of the profile accepts it: in `"minimum"` and `"basic-wl"`, and with a warning in `"basic"` and `"en16931"` (`IP-CODE-01`), as a validator with the current list, such as KoSIT, rejects it; `"xrechnung"` rejects it (`BR-CL-04`).
- Any other code the newest list has withdrawn is rejected even where the validation of the profile still accepts it: the electronic address scheme `9901` in every profile (`IP-CODE-01` in `"basic-wl"` and `"basic"`).
- A code that only the newest list has, e.g. the Caribbean guilder `XCG` (2025), is reported as a code the validation of the profile does not know yet.

## Rules of invoice-pro

Besides the official rules (`BR-*`, `BR-DE-*`, `PEPPOL-*`, `CII-SR-*`), `invoice-pro` checks some rules of its own, whose ids start with `IP-`. Here it is stricter than the official validators: they accept the XML, but a value the invoice states would be lost or wrong, or the law requires more than the profile checks.

They follow from the principle that the printed invoice and its XML are one invoice (see [How It Works](./architecture.md#the-printed-invoice-and-its-xml-are-one-invoice)), and from the details the law requires on an invoice.

[//]: # "Generated from tools/zugferd/registry.json by tools/zugferd/registry.py --write-docs; edit the registry instead."

| Rule            | Level   | Checks                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| :-------------- | :------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `IP-ADDR-01`    | error   | A city line with a number of three or more digits, but no post code in the format of the party's country (e.g. "1012 Amsterdam" instead of "1012 AB Amsterdam"): the post code would be missing, and the number would be written into the city name.                                                                                                                                                                                           |
| `IP-CODE-01`    | error   | A code that the newest EN 16931 code list (1.3.16) has withdrawn, which the Factur-X validation of the profile still accepts, but a validator with the current list rejects, as KoSIT does: a currency such as BGN or HRK (replaced by the euro) is allowed with a warning in BASIC and EN 16931 (in XRechnung it is `BR-CL-04`); the electronic address scheme 9901 is an error in BASIC WL and BASIC (in EN 16931 and XRechnung `BR-CL-25`). |
| `IP-COUNTRY-01` | error   | A party without `country` whose VAT identifier was issued by another country: the country of the locale would be written (e.g. "DE" for the Austrian VAT ID "ATU12345678"). Set `country` on the party, also for a foreign VAT registration.                                                                                                                                                                                                   |
| `IP-DEC-01`     | error   | A VAT rate with more than 4 decimals, which the XML cannot state exactly (and which could collide with another VAT group).                                                                                                                                                                                                                                                                                                                     |
| `IP-DEC-02`     | error   | An amount with more than 2 decimals, e.g. of a currency such as KWD (reported for `currency`) or of a locale that rounds money more finely: the XML states amounts with 2 decimals (`BR-DEC-*`), so it would state another amount than the invoice prints, and the amounts would no longer add up.                                                                                                                                             |
| `IP-DOC-01`     | error   | A subject that names another kind of document than an invoice (e.g. "Gutschrift", "Angebot", "Credit note", "Devis") without `document-type`: the e-invoice would state a commercial invoice that asks the buyer to pay. See [Document Type](./invoice-data/document.md#document-type-bt-3).                                                                                                                                                   |
| `IP-DOC-02`     | error   | A corrected invoice (`document-type: "corrected"`) without `preceding-invoice-nr`: it replaces an invoice, which the VAT Directive (Art. 219) requires it to name. XRechnung checks it as `BR-DE-26`.                                                                                                                                                                                                                                          |
| `IP-DOC-03`     | error   | A credit note with a negative total: it states the credited amounts as positive amounts, so it would ask the buyer to pay.                                                                                                                                                                                                                                                                                                                     |
| `IP-DOC-04`     | warning | An invoice with a negative total: valid, but a credit note (`document-type: "credit-note"`) is the document for a credit.                                                                                                                                                                                                                                                                                                                      |
| `IP-DOC-05`     | error   | A `preceding-invoice-date` without `preceding-invoice-nr`: the e-invoice states a preceding invoice (BG-3) by its number (BT-25), so its date (BT-26) would be lost.                                                                                                                                                                                                                                                                           |
| `IP-EADDR-01`   | warning | An EN 16931 invoice without the electronic address of the seller (BT-34) or the buyer (BT-49): EN 16931 leaves them optional, but a delivery over Peppol requires them, which XRechnung checks as `PEPPOL-EN16931-R020` and `R010`.                                                                                                                                                                                                            |
| `IP-ID-01`      | error   | An identifier of the [`id` module](../api-reference/invoice/identifiers.md) whose format or check digit is wrong, e.g. a SIRET with a typo. `id.custom(..)` takes an identifier unchecked.                                                                                                                                                                                                                                                     |
| `IP-ID-02`      | error   | Two values for one party identifier, of which only one can be written: a `global-id` without scheme next to `id`, a `location-id` next to `id` of the delivery address, or two identifiers with scheme.                                                                                                                                                                                                                                        |
| `IP-ID-03`      | error   | An identifier given for a field it does not belong to: a Leitweg-ID as party identifier or legal registration identifier, another identifier as `leitweg-id`, a GLN or D-U-N-S number as `legal-id`, or a register number as `id`.                                                                                                                                                                                                             |
| `IP-KEY-01`     | warning | A key of `sender`, `recipient`, `delivery-address`, `sender.tax-representative` or `payee` that `invoice-pro` does not know: its value is not written into the e-invoice.                                                                                                                                                                                                                                                                      |
| `IP-KEY-02`     | error   | A misspelled key the e-invoice reads, or another name of it (e.g. `vatId`, `vat_id`, `ustid`, `uid`, `e-mail`, `siret` or `zip`): its value would be missing without notice.                                                                                                                                                                                                                                                                   |
| `IP-PAY-01`     | error   | An IBAN with wrong check digits or format in `bank-details` or as `debtor-iban` of `direct-debit`: the amount could not be paid or collected. XRechnung's `BR-DE-19` and `BR-DE-20` check it as warnings only.                                                                                                                                                                                                                                 |
| `IP-PAY-02`     | error   | A SEPA creditor identifier (BT-90) of `direct-debit` with wrong check digits or format.                                                                                                                                                                                                                                                                                                                                                        |
| `IP-PAY-05`     | error   | A `payee` that is the seller (its name, identifier or legal registration identifier) in `"basic-wl"`: the payee (BG-10) is someone other than the seller (`BR-17`), which the validation of the profile does not check.                                                                                                                                                                                                                        |
| `IP-PAY-06`     | error   | An invoice with an amount due (BT-115) has a payment due date (BT-9) or payment terms (BT-20): BR-CO-25 of EN 16931, which the CEN Schematron 1.3.16 and Factur-X 1.09 no longer check in CII.                                                                                                                                                                                                                                                 |
| `IP-PERIOD-01`  | error   | A printed service period that is not the one the XML states: another date, or a text of its own where the XML states the invoice date. A text of its own besides dated items or a `service-period` is a warning. See [Service Period](./invoice-data/document.md#service-period-bt-72--bg-14).                                                                                                                                                 |
| `IP-PERIOD-02`  | warning | The date of an item outside the `service-period` of the invoice. XRechnung checks it for an invoicing period (BG-14) as `PEPPOL-EN16931-R110` and `R111`. See [Item Notes, Periods and Country of Origin](./invoice-data/line-items.md#item-notes-periods-and-country-of-origin).                                                                                                                                                              |
| `IP-PERIOD-03`  | error   | The printed invoice does not show the date of the supply, which German law requires on every invoice but a small-amount invoice; for a seller elsewhere a warning where it is not the invoice date. See [Printed Details](#printed-details).                                                                                                                                                                                                   |
| `IP-PREPAID-01` | warning | Prepayments (BT-113) above the invoice total, so that the amount due (BT-115) is negative: valid, but most likely not intended.                                                                                                                                                                                                                                                                                                                |
| `IP-PRINT-02`   | error   | Amounts printed in another currency than the invoice currency (BT-5), e.g. a custom locale that prints "zł" while the XML states EUR.                                                                                                                                                                                                                                                                                                          |
| `IP-PRINT-03`   | error   | The XML states the seller's VAT identifier (BT-31) or tax number (BT-32), one of which the law requires on the invoice, but the printed invoice shows neither. See [Printed Details](#printed-details).                                                                                                                                                                                                                                        |
| `IP-PROFILE-01` | warning | An input the profile cannot state, e.g. the buyer trading name (BT-45) in `"basic"`, or `notes`, a `payee` or the method of `paid` in `"minimum"`: the invoice may print it, but it is not written into the e-invoice. The hint names the lowest profile that states it.                                                                                                                                                                       |
| `IP-TAX-01`     | error   | `tax: none` in an e-invoice: the items would be declared as zero rated (`Z`). Use `tax.zero()`, `tax.exempt(grounds: ..)`, `tax.outside-scope()` or `tax-exempt-small-biz`.                                                                                                                                                                                                                                                                    |
| `IP-TAX-02`     | error   | A VAT exemption reason code (BT-121, `code` of the `tax` module) of another VAT category, e.g. `"VATEX-EU-IC"` on an exemption (`E`), or on a taxed category (`S`, `Z`, `L`, `M`). See [Tax Category Codes](./invoice-data/taxes.md#tax-category-codes).                                                                                                                                                                                       |
| `IP-TAX-03`     | warning | Items of one VAT category and rate with different exemption reason codes: EN 16931 states one code per VAT group, so the reasons are stated as text (BT-120) only.                                                                                                                                                                                                                                                                             |
| `IP-TAX-04`     | error   | An exemption (`E`) with an exemption reason code but without `grounds`: the printed invoice must state why no VAT is charged (§ 14 Abs. 4 Satz 1 Nr. 8 UStG, Art. 226 No. 11 of the VAT Directive).                                                                                                                                                                                                                                            |
| `IP-TAX-05`     | error   | A seller tax representative (BG-11) with a VAT identifier on an invoice not subject to VAT (`O`) in `"basic-wl"`: EN 16931 excludes that identifier for items not subject to VAT (`BR-O-02`), which the validation of the profile does not check, as it states no lines.                                                                                                                                                                       |
| `IP-UNIT-01`    | warning | A unit code used verbatim that is also a common German abbreviation of another unit (`STK`, `PAL`, `FL`, `GL`, `KT`).                                                                                                                                                                                                                                                                                                                          |
| `IP-UNIT-02`    | error   | A unit given as text that invoice-pro does not know (e.g. "Nacht"): the e-invoice would state it as "one" (`C62`), a guess the validators accept. Give the unit with its code, e.g. `(display: "Nacht", code: "C62")`.                                                                                                                                                                                                                         |
| `IP-VAT-138`    | warning | An intra-community supply (`K`) that does not go to another member state: a deliver-to country (BT-80) that is the seller's own country (or, for a seller without VAT identifier of its own, the country of its tax representative), or a buyer VAT identifier not issued by an EU member state (or "XI" for Northern Ireland).                                                                                                                |
| `IP-VAT-226`    | error   | An intra-community supply (`K`) or a cross-border reverse charge (`AE`) without the buyer VAT identifier (Art. 226 No. 4 VAT Directive), which the official rules miss: in BASIC WL (no invoice lines) and with a buyer `legal-id`; a tax representative without address (No. 15).                                                                                                                                                             |

## The `zugferd-errors` Parameter

The `zugferd-errors` parameter of `invoice` decides what happens with the problems:

| Value               | Behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| :------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"panic"` (default) | Errors stop the compilation with the list shown above (including any warnings). An invoice with warnings only compiles.                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `"report"`          | Errors and warnings are listed in a box at the top of the invoice instead of stopping the compilation, which is handy while filling in the data in the preview. If the theme shows no report, errors stop the compilation as with `"panic"` (see [Custom Report Layout](#custom-report-layout)). The XML of an invoice with errors is attached as a draft: as `invoice-draft.xml` instead of `factur-x.xml` (or `xrechnung.xml`) and with the relationship `"data"`, so that no receiving software takes it for the e-invoice. With warnings only, the XML is attached as usual. |
| `"ignore"`          | The check is skipped on purpose: the XML is attached as usual (`factur-x.xml` or `xrechnung.xml`, relationship of the profile), whatever its errors. It may then be invalid, and you are responsible for it. Use this only if you validate the XML yourself, e.g. when a recipient explicitly accepts a deviation.                                                                                                                                                                                                                                                               |

A missing or invalid IBAN in [`bank-details`](../api-reference/components.md#bank-details), or an invalid IBAN or creditor identifier of a [`direct-debit`](../api-reference/components.md#direct-debit), makes the printed invoice wrong as well, so it stops the compilation with a message naming it, also with `"ignore"`. With `"report"`, it is marked where it is printed instead (a placeholder takes the place of the EPC-QR code), and the report lists it as an error (`BR-DE-19` or `BR-DE-20` in XRechnung, `IP-PAY-01` or `IP-PAY-02` otherwise), so the XML is attached as a draft.

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

## Custom Report Layout

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

## Printed Details

The printed invoice and its XML are one invoice, so the printed invoice shows what the XML states and the law requires on an invoice:

- **The seller's tax number or VAT identifier** (`IP-PRINT-03`, § 14 Abs. 4 Satz 1 Nr. 2 UStG, Art. 226 No. 3 of the VAT Directive): an error if the XML states the seller's VAT identifier (BT-31) or tax number (BT-32), but the printed invoice shows neither. A small-amount invoice of at most 250 euros needs neither by German law (§ 33 UStDV), but it shows what its XML states as well.
- **The date of the supply** (`IP-PERIOD-03`): for a seller in Germany an error, as the law requires it on every invoice, also when it is the date of the invoice (§ 14 Abs. 4 Satz 1 Nr. 6 UStG), except on a small-amount invoice of at most 250 euros that is no intra-community supply or reverse charge (§ 33 UStDV). For a seller elsewhere, and on a small-amount invoice, it is a warning where the date of the supply is not the date of the invoice (Art. 226 No. 7 of the VAT Directive). A credit note, which amends an invoice, is not checked, nor is a prepayment invoice, which precedes the supply (§ 14 Abs. 5 UStG asks for the date of the payment only if it is known).

The default `references` and every [preset](../api-reference/invoice/references.md#preset-packages) print both. A detail counts as shown in a reference sign of any title (e.g. `references.seller-vat-id()`, `references.service-time()` or `("Lieferdatum", "01.09.2026")`), in the name and address lines or the `extra` of the sender or the recipient, in the text of the invoice (e.g. `#info.sender.vat-id`) and, for the date of the supply, with the dates of the items. Identifiers are compared without spaces, and the date of the supply as the XML states it, in the date format of the locale: a sentence such as "Leistungsdatum entspricht Rechnungsdatum" is not recognized, so print the date with `references.service-time()`. The invoice date does not count as the date of the supply.

`invoice-pro` knows what the page shows only for a theme that says what it prints (`prints`, see [What the Theme Prints](../api-reference/theme.md#what-the-theme-prints)): the DIN-5008 theme prints the reference signs and the `extra` of the parties. The blank theme and themes without `prints` are not checked, and neither is `IP-PRINT-03` with a `header` or `footer` of the theme, which may show the tax number. A page header or footer of your own (`set page(header: ..)`) cannot be read: give company details such as the tax number as the `footer` of the theme instead, e.g. `themes.DIN-5008(footer: ..)`.

```typst
#import "@preview/invoice-pro:0.5.0": *

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
