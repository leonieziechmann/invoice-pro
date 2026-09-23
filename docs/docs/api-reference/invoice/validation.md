---
sidebar_position: 3
---

# Validation

invoice-pro checks every invoice for legally required data and for output the theme must carry. The `validation` parameter of [`invoice`](./index.md) decides what happens with a problem: the theme decides what counts as one, the document decides how strict to be.

## Levels

| Level               | Output                                                                                                                                                                                                                                                                  | Use for                              |
| :------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------- |
| `"draft"` (default) | The document renders. Missing data is marked inline, every page carries a badge and a watermark, and a report page lists each problem with its legal basis. The ZUGFeRD XML is withheld while data is missing. A complete document renders exactly as under `"strict"`. | writing, previews                    |
| `"strict"`          | The build stops and lists every problem.                                                                                                                                                                                                                                | sending, CI, batch pipelines         |
| `none`              | No checks. The document renders what it was given. With `zugferd` set, the XML is attached even when required data is missing.                                                                                                                                          | thumbnails, tests; never for sending |

```typst
#import "@preview/invoice-pro:0.4.2": *

// draft (the default): the invoice renders, the gaps are marked, a report page follows
#show: invoice.with(
  locale: locale.en-de,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Muster AG"), // no address
  invoice-nr: none, // missing
  zugferd: "basic", // withheld while data is missing
  validation: "draft", // "strict" stops the build; none checks nothing
)

#line-items[
  #item([Corporate design concept], price: 1800)
]
```

![A draft with the badge, the watermark and inline markers, and the report page after the invoice](/img/themes/fig-validation.png)

## Overriding the Level from the Command Line

`--input invoice-pro-validation=strict|draft|none` overrides the parameter in both directions, so a pipeline can enforce `strict` without editing the documents:

```bash
# fail the job on any incomplete invoice
typst compile --input invoice-pro-validation=strict invoice.typ

# render thumbnails without markers
typst compile --input invoice-pro-validation=none --pages 1 invoice.typ thumbnail.png
```

Under `strict`, the example above stops with:

```text
invoice-pro found 2 problems (validation: "strict"; preview them with validation: "draft" or --input invoice-pro-validation=draft):
  1. invoice::invoice-nr is missing; every invoice needs a unique, sequential number (§ 14 Abs. 4 Nr. 4 UStG; EN 16931 BT-1)
  2. invoice::recipient has no address (`address`, `city`); the recipient's full address is required (§ 14 Abs. 4 Nr. 1 UStG; EN 16931 BG-8)
```

A single problem is reported with its message alone. An invalid value panics; common synonyms get a hint: `visual`, `warn` → `"draft"`; `panic`, `error` → `"strict"`; `off`, `false` → `none`.

## What Is Checked

Every problem that follows the level belongs to one of four classes:

| Class       | What                                                               | Examples (issue ids)                                                                                                                                                                     | Withholds the XML in a draft |
| :---------- | :----------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------- |
| `data`      | A legally required invoice field is missing (§ 14 UStG, EN 16931). | `invoice-number`, `sender-name`, `sender-address`, `sender-tax-id`, `recipient-name`, `recipient-address`, `line-items`, `recipient-vat-id` (reverse charge), `iban` (invalid)           | yes                          |
| `e-invoice` | Data the selected ZUGFeRD / Factur-X profile requires is missing.  | `e-invoice/buyer-address`, `e-invoice/seller-address` (electronic addresses), `e-invoice/buyer-reference`, `e-invoice/seller-contact-*`                                                  | yes                          |
| `theme`     | The theme cannot carry required output.                            | `theme/role-*`, `theme/part-*`, `theme/empty-*`, `theme/identity-number`, `theme/identity-date`                                                                                          | no                           |
| `lint`      | A quality or export guard.                                         | `lint/contrast-*`, `lint/footer-fit`, `lint/overprint-*`, `lint/window-*`, `lint/envelope-*`, `lint/qr-bill-paper`, `lint/fine-size`, `lint/logo-alt`, `lint/pdf-image-*`, `lint/cmyk-*` | no                           |

The data checks of an invoice:

| Id                  | Checks                                                                                   | Legal basis (DE)       | EN 16931     |
| :------------------ | :--------------------------------------------------------------------------------------- | :--------------------- | :----------- |
| `invoice-number`    | `invoice-nr` is set.                                                                     | § 14 Abs. 4 Nr. 4 UStG | BT-1         |
| `sender-name`       | `sender.name` is set.                                                                    | § 14 Abs. 4 Nr. 1 UStG | BT-27        |
| `sender-address`    | `sender.address` or `sender.city` is set.                                                | § 14 Abs. 4 Nr. 1 UStG | BG-5         |
| `sender-tax-id`     | `sender.vat-id` or `sender.tax-nr` is set.                                               | § 14 Abs. 4 Nr. 2 UStG | BT-31, BT-32 |
| `recipient-name`    | `recipient.name` is set.                                                                 | § 14 Abs. 4 Nr. 1 UStG | BT-44        |
| `recipient-address` | `recipient.address` or `recipient.city` is set.                                          | § 14 Abs. 4 Nr. 1 UStG | BG-8         |
| `line-items`        | The invoice has at least one line item.                                                  | § 14 Abs. 4 Nr. 5 UStG | BG-25        |
| `recipient-vat-id`  | `recipient.vat-id` is set when reverse charge or an intra-community supply applies.      | § 14a Abs. 1, 3 UStG   | BT-48        |
| `iban`              | The IBAN of `bank-details` has valid check digits. An invalid IBAN also gets no QR code. | –                      | BT-84        |

With a locale for AT, CH, FR, IT or ES, the report cites the national invoicing rule instead of the German one. The checks read the normalized parties, so every spelling of an address (`address` or `street`, a string or a dictionary for `city`) is covered.

:::warning
The checks cover the fields listed above. They do not replace a tax adviser, and the delivery date (§ 14 Abs. 4 Nr. 6 UStG) is not checked.
:::

**Misuse always stops the build**, at every level, including `none`: unknown keys, wrong types, unknown parts, undefined geometry, malformed envelopes. No output could honour such input.

## What a Draft Shows

All feedback is drawn by the core in fixed colors (a contrast of at least 6.6:1), so no theme can hide it.

| Element        | Description                                                                                                                                                    |
| :------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inline markers | ‹missing: invoice number›¹ in place of the missing field, in every theme. They are real text with the number of their report row; in the flow they link to it. |
| Badge          | "DRAFT · 2 problems" at the top of every page, with "· no e-invoice" when the XML was withheld.                                                                |
| Watermark      | A faint diagonal "DRAFT" behind every invoice page, which survives printing when the badge falls into the printer's margin.                                    |
| Report page    | After the invoice and outside its page count: number, class, problem, legal basis and fix of every problem, plus a notice when the XML was withheld.           |
| PDF keywords   | "Draft" is added; "ZUGFeRD" and "Factur-X" are dropped when the XML was withheld.                                                                              |

Problems found while rendering (a footer that does not fit, a title that does not show the invoice number, a required part that renders nothing) are counted and reported like the ones known up front.

Several invoices in one document are checked one by one: each draft gets its own badge, markers, page numbers and report page, and a complete invoice among them shows no feedback.

## ZUGFeRD / Factur-X

| Level      | With `zugferd` set                                                                                                                                                                                                                                                    |
| :--------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"draft"`  | The `factur-x.xml` is attached only when no `data` or `e-invoice` problem is open. Otherwise it is withheld, and the badge and the report say so: a receiving system would book an incomplete data set automatically. `theme` and `lint` problems do not withhold it. |
| `"strict"` | Every problem stops the build, so an attached XML is always complete.                                                                                                                                                                                                 |
| `none`     | No check runs, and the XML is attached as built, even when required data is missing ("off means off"). Never send such a document.                                                                                                                                    |

The e-invoice checks depend on the profile: `en16931` and `xrechnung` need electronic addresses for buyer and seller (derived from a VAT ID or an e-mail address); `xrechnung` (and `en16931` between two German parties) also needs a buyer reference and a seller contact with name, phone and e-mail. See [E-Invoicing](../../e-invoicing.md).

## Themes and `theme.resolve`

The theme's own problems (a layout that does not place the recipient, contrast below `checks.min-contrast`, a footer that does not fit) are issues too and follow the same level. [`theme.resolve`](../theme/parts.md#testing-a-theme-themeresolve) defaults to `validation: "strict"`, so the CI of a theme package fails on a non-compliant theme.

## Localized Report

The markers, the badge, the watermark and the report are localized (`de`, `en`, `fr`, `it`, `es`) through the locale group `strings.validation`. The messages of `strict` stay in English. To change a text, patch the locale with a dictionary:

```typst
#show: invoice.with(
  locale: locale.en-de.with((
    strings: (validation: (marker: field => [‹to do: #field›])),
  )),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The keys of the group are listed in the [Base Schema](../locale/base.md#validation). The locale merge is two levels deep: a patch of `fields`, `issues`, `roles` or `classes` replaces that whole dictionary, so copy it completely when you change one entry.
