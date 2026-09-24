---
sidebar_position: 1
---

# Invoice API

The `invoice` function is the main entry point of the `invoice-pro` package. It sets up the page layout, visual theme, localization settings, and the global tax configuration for the entire document.

:::info
Every invoice document must start with a `#show: invoice.with(..)` rule. All other components, such as `line-items` or [`payment-goal`](../components.md#payment-goal), must be placed **after** this show rule.

If you forget the show rule, your components will remain invisible because they rely on the underlying `loom` state engine to render properly.
:::

---

## `invoice`

Initializes the document and orchestrates the data calculation passes.

| Key                    | Type                                                                                         | Description                                                                                                                                                                                                                                                                                                                                               |
| :--------------------- | :------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `theme`                | `function`                                                                                   | The visual theme to apply to the invoice. See [Themes](#theme) below.                                                                                                                                                                                                                                                                                     |
| `locale`               | `function`                                                                                   | The locale settings for language and number formatting. See [Locales](#locale) below.                                                                                                                                                                                                                                                                     |
| `currency`             | `auto` \| `str`                                                                              | The currency of the invoice, an ISO 4217 code such as `"USD"`: the e-invoice states it (BT-5), and the amounts are printed with its symbol (`$`, `£`, `¥`, ...) or its code (e.g. `CHF`) in the number format of the locale. `auto` is the currency of the locale. See [Currency](../../e-invoicing.md#13-currency-bt-5).                                 |
| `sender`               | `dictionary`                                                                                 | Sender details (e.g., name, address, contact info).                                                                                                                                                                                                                                                                                                       |
| `recipient`            | `dictionary`                                                                                 | Recipient details (e.g., name, address, customer ID).                                                                                                                                                                                                                                                                                                     |
| `delivery-address`     | `none` \| `dictionary`                                                                       | Separate delivery or shipping address (e.g., if different from billing address), with the same keys as `recipient`. Can also be given as `recipient.delivery-address`. Without its own `country`, it is in the recipient's country. In Factur-X / ZUGFeRD, maps to BG-13 (`ram:ShipToTradeParty`).                                                        |
| `payee`                | `none` \| `dictionary`                                                                       | Who receives the payment instead of the seller, e.g. a factoring company: `(name: .., id: .., global-id: .., legal-id: ..)`. Printed by the default `references` (`references.payee()`) and as the account holder of `bank-details`; in Factur-X / ZUGFeRD, maps to BG-10 (`ram:PayeeTradeParty`). See [Payee](../../e-invoicing.md#1-party-information). |
| `date`                 | `datetime`                                                                                   | The date of the invoice. Defaults to `datetime.today()`.                                                                                                                                                                                                                                                                                                  |
| `service-period`       | `none` \| `datetime` \| `array`                                                              | The date or period `(start, end)` of the supply, printed by `references.service-time()` and written to Factur-X / ZUGFeRD (BT-72 / BG-14). If `none`, the earliest to the latest `date` of the items, or the invoice date if no item has one (not on a credit note, which then states none).                                                              |
| `subject`              | `str` \| `content` \| `auto`                                                                 | The subject line of the invoice. If `auto`, the title of the `document-type` in the language of the [locale](../locale/index.md) (e.g., "Rechnung" in German).                                                                                                                                                                                            |
| `document-type`        | `auto` \| `str` \| `int`                                                                     | The type of the document: `"invoice"` (default), `"credit-note"`, `"corrected"`, `"prepayment"`, `"self-billed"` or a UNTDID 1001 code. Sets the printed title and, in Factur-X / ZUGFeRD, BT-3. See [`document-type`](#document-type) below.                                                                                                             |
| `references`           | `auto` \| `none` \| `dictionary` \| `array`                                                  | Reference information for the document header (e.g., customer number, order date). Accepts a dictionary of key-value pairs or an array of `(label, value)` tuples. See [`references`](#references) below for the default (`auto`).                                                                                                                        |
| `invoice-nr`           | `none` \| `str` \| `content`                                                                 | The unique identifier or number of the invoice.                                                                                                                                                                                                                                                                                                           |
| `notes`                | `none` \| `str` \| `content` \| `array`                                                      | Notes about the invoice as a whole: a text, or an array of texts and dictionaries `(text: .., subject-code: ..)`. Printed below the line items and, in Factur-X / ZUGFeRD, written as BT-22 (with the UNTDID 4451 subject code as BT-21).                                                                                                                 |
| `payment-reference`    | `none` \| `str` \| `content`                                                                 | The payment reference / purpose (Verwendungszweck). Used by [`bank-details`](../components.md#bank-details), the EPC-QR code and the ZUGFeRD XML (BT-83) unless `bank-details` sets its own `reference` or `text`. Defaults to the `invoice-nr`.                                                                                                          |
| `tax`                  | `auto` \| `ratio` \| `dictionary` \| `none`                                                  | The default tax rate for the document. See [Tax](#tax--tax-exempt-small-biz) below.                                                                                                                                                                                                                                                                       |
| `tax-mode`             | `"exclusive"` \| `"inclusive"`                                                               | Sets the global baseline for tax calculation. `"exclusive"` treats standard prices as net. `"inclusive"` treats standard prices as gross.                                                                                                                                                                                                                 |
| `tax-exempt-small-biz` | `bool`                                                                                       | If `true`, applies the small business tax exemption logic based on the selected locale.                                                                                                                                                                                                                                                                   |
| `zugferd`              | `none` \| `auto` \| `"minimum"` \| `"basic-wl"` \| `"basic"` \| `"en16931"` \| `"xrechnung"` | _(Experimental)_ Embeds a machine-readable ZUGFeRD / Factur-X XML into the PDF. Requires compiling with `--pdf-standard=a-3b`.                                                                                                                                                                                                                            |
| `zugferd-errors`       | `"panic"` \| `"report"` \| `"ignore"`                                                        | What to do when the e-invoice data violates the rules of the profile: stop with a list of all problems (default), list them in the document and attach the XML as a draft, or attach it anyway. See [Validation and Error Reporting](../../e-invoicing.md#validation-and-error-reporting).                                                                |
| `body`                 | `content`                                                                                    | The content of the invoice, containing your containing your [`line-items`](../line-items/index.md) and other layout components.                                                                                                                                                                                                                           |

## Key Parameters Explained

While the table above lists all available options, a few parameters dictate the core behavior, layout, and legal compliance of your invoice:

### `sender` & `recipient`

These parameters define the contact details for the invoicing party (sender) and the customer (recipient). Both parameters accept a standard dictionary.

Standard keys generally include `name`, `address`, and `city`. Additionally, you can use the `extra` key to provide arbitrary supplementary information (like phone numbers, email addresses, or commercial register numbers) styled according to your theme.

Just like the header `references`, the `extra` field accepts either a dictionary of key-value pairs or an array of `(label, value)` tuples.

For e-invoices, both parties take more keys: `vat-id`, `tax-nr` (sender), `id` and `global-id`, the legal registration identifier `legal-id` (e.g. `id.siret(..)` or `id.register(..)` of the [`id` module](./identifiers.md)), `trading-name`, `legal-info` (sender), `contact`, `electronic-address`, `buyer-reference` or `leitweg-id` (recipient) and the seller's `tax-representative`. See [Party Information](../../e-invoicing.md#1-party-information). The built-in themes do not print the legal registration identifier, the trading name, the legal information and the tax representative; see [Printing Identifiers](./identifiers.md#printing-identifiers).

#### Polymorphic Address Support

The `address` key is polymorphic, accepting strings, content blocks, or arrays of string/content:

- **`str` or `content`**: A single-line address (e.g. `"Musterstraße 1"` or `[Musterstraße 1]`).
- **`array`**: Multiple address lines (e.g. `("Musterstraße 1", "Hinterhaus 2")`).

**Layout Formatting:**

- In vertical layouts (e.g., envelope address window block), lines are separated by line breaks (`\`).
- In horizontal layouts (e.g., inline details block), lines are separated by commas (`", "`).

**Example:**

```typst
sender: (
  name: "Max Mustermann",
  address: ("Musterstraße 1", "Hinterhaus 2"),
  city: "12345 Musterstadt",
  extra: (
    "Phone": "+49 123 456789",
    "Email": "max@mustermann.de",
    "Web": "www.mustermann.de"
  )
),
recipient: (
  name: "Acme Corporation",
  address: "Business Blvd 42",
  city: "54321 Metropolis",
  extra: (
    ("Contact Person", "Jane Doe"),
    ("Department", "Accounting")
  )
)
```

:::tip
To configure country-specific formatting for the address block (like UK postcodes or US state formats) and specify the ZUGFeRD-compliant country code, set `country` on the party: a predefined country of the `country` module (e.g. `country.fr`), an ISO code (e.g. `"FR"`) or `country.custom(..)`. Without `country`, the party is in the country of the locale region. See the [Country API](./country.md) subpage for detailed specifications.
:::

### `locale`

The locale system dictates the language of standard text (like "Invoice" or "Subtotal"), currency formatting, and the default tax rates for your region.

Locales are structured as `locale.<lang>-<region>`.

- **Available Languages (`<lang>`)**: `de` (German), `en` (English), `fr` (French), `it` (Italian), `es` (Spanish).
- **Available Regions (`<region>`)**: `de` (Germany), `at` (Austria), `ch` (Switzerland), `fr` (France), `it` (Italy), `es` (Spain).

**Example:** `locale: locale.en-de` (English language formatting, but German regional tax defaults).

_See the [Locale API Reference](../locale/index.md) for the full list and customization options._

### `theme`

The theme dictates the visual layout and styling of your invoice. You must pass a theme function from the `themes` module.

:::note
The theming engine is currently undergoing expansion. At the moment, there are two primary themes available:

- `themes.DIN-5008()`: A standard German business letter layout.
- `themes.base`: A minimal, bare-bones layout.
  :::

_See the [Theme API Reference](../theme.md) for more details._

### `tax` & `tax-exempt-small-biz`

By default (when `tax` is set to `auto`), the system fetches the standard VAT/GST rate from your selected `locale` region. However, you can explicitly override this default at the document root by providing a simple percentage (e.g., `19%`) or using a specialized code from the `tax` module (e.g., `tax.vat(21%)`).

`tax: none` defines no tax at all: items without their own `tax` are printed with 0%, but without a tax category that says why no VAT is charged. Use it for simple documents only; for e-invoices, choose the category with the `tax` module (see [No Tax](../tax.md#no-tax-tax-none)).

If you run a small business that is exempt from charging VAT (e.g., the _Kleinunternehmerregelung_ in Germany), you can simply set `tax-exempt-small-biz: true`.

:::note
If you enable the small business exemption, the system automatically applies the correct legal tax code, legal note and 0% rate for your region (for e-invoices: category E in Germany, Austria, France and Spain, O in Italy and Switzerland, see [Small Business Exemption](../../e-invoicing.md#small-business-exemption)). Therefore, you should leave the `tax` parameter set to `auto`. If you manually set a custom `tax` rate while `tax-exempt-small-biz` is `true`, the compiler will throw an error to prevent conflicting configurations.
:::

_See the [Tax Module API Reference](../tax.md) for a detailed breakdown of all available tax codes and margin schemes._

### `document-type`

The document type says what kind of document the invoice is. Unless you set `subject`, it is the printed title, in the language of the locale:

| `document-type`       | Title (German / English)                 | Meaning                                                                              |
| :-------------------- | :--------------------------------------- | :----------------------------------------------------------------------------------- |
| `auto` or `"invoice"` | Rechnung / Invoice                       | A commercial invoice (UNTDID 1001 code `380`).                                       |
| `"credit-note"`       | Rechnungskorrektur / Credit Note         | Credits amounts to the buyer (`381`). Enter the credited items with positive prices. |
| `"corrected"`         | Korrigierte Rechnung / Corrected Invoice | Replaces the invoice `preceding-invoice-nr` (`384`).                                 |
| `"prepayment"`        | Anzahlungsrechnung / Prepayment Invoice  | Asks for an advance payment (`386`).                                                 |
| `"self-billed"`       | Gutschrift / Self-Billing Invoice        | Issued by the buyer for the seller (`389`): `sender` is the buyer.                   |

Any other UNTDID 1001 code of an invoice or credit note is accepted as text (e.g. `"326"` for a partial invoice) and printed with the title of its kind.

On a credit note and a self-billed invoice, the sender pays the amount to the recipient: [`payment-goal`](../components.md#payment-goal) says so, and the [`bank-details`](../components.md#bank-details) are the recipient's account (its name, or on a self-billed invoice the name of the `payee`, is the default account holder) without EPC-QR code. The titles can be changed with [`locale.custom.document`](../locale/custom.md), the payment sentence with `locale.custom.payment(text-credit: ..)`.

```typst
#show: invoice.with(
  document-type: "credit-note",
  preceding-invoice-nr: "INV-2026-102",
  // ...
)
```

See [Document Type](../../e-invoicing.md#9-document-type-bt-3) in the e-invoicing guide for credit notes, self-billed invoices and the e-invoice.

### `references`

The `references` parameter configures the reference information / Leitzeichen block in the document header (e.g. Customer No., Order Date, Due Date, or Leitweg-ID).

By default (`auto`), the block shows what the law requires on an invoice besides the parties and the items (§ 14 Abs. 4 UStG in Germany, Art. 226 of the VAT Directive), with net (B2B) and gross prices (B2C) alike, and what the e-invoice states:

- the seller's tax number and VAT ID and the buyer's VAT ID: the sender's and the recipient's, and on a self-billed invoice the tax number and VAT ID of the seller (the recipient) and the VAT ID of the buyer (the sender). An invoice of up to 250 EUR may leave out the seller's (§ 33 UStDV); `invoice-pro` prints them whenever they are given, which the e-invoice states as well;
- the date of the supply (`service-time`): the `service-period` if you give it and, for a seller in Germany, in any case (§ 14 Abs. 4 Satz 1 Nr. 6 UStG requires it also when it is the date of the invoice): the dates of the items, or the invoice date if no item has one (not on a credit note, whose date is not the date of the supply), as the e-invoice states it (BT-72, BG-14);
- the `payee`, if you name one;
- the `preceding-invoice-nr` and the `preceding-invoice-date`, if you give them.

Earlier versions printed no tax identifiers for gross prices and the date of the supply only for an explicit `service-period`.

You can supply references in four formats:

- **Preset Packages (Recommended):** Use ready-made, localized presets like `references.preset-b2b()`, `references.preset-b2g()`, `references.preset-project()`, or `references.preset-din-5008()`. Unpopulated fields are automatically omitted.
  ```typst
  #show: invoice.with(
    references: references.preset-b2b(),
    customer-nr: "KD-12345",
    order-nr: "PO-9988",
    // ...
  )
  ```
- **Dynamic Builder Functions:** Explicitly select, order, or customize individual reference fields from the `references` module:
  ```typst
  references: (
    references.invoice-nr(),
    references.customer-nr(),
    references.order-nr(),
    references.due-date(),
  )
  ```
- **As an Array of Tuples:** For static custom key-value pairs in a strict order.
  ```typst
  references: (
    ("Customer No.", "C-9982"),
    ("Order Date", "2026-04-10"),
  )
  ```
- **As a Dictionary:** For key-value mapping with custom labels.
  ```typst
  references: (
    "Our Reference": references.invoice-nr,
    "Your Account": "C-9982",
  )
  ```

👉 **[See the full Dynamic References Guide](./references.md)** for the complete list of available reference signs, preset packages, and customization options.

### `zugferd` — ZUGFeRD / Factur-X _(Experimental)_

:::warning
ZUGFeRD / Factur-X support is **experimental**. The generated XML has not yet been validated against all edge cases of the EN 16931 standard. Do not rely on it for legally binding e-invoices without independent validation.
:::

Setting `zugferd` to a profile string embeds a machine-readable `factur-x.xml` file (`xrechnung.xml` in the XRechnung profile) inside the PDF according to the ZUGFeRD 2.x / Factur-X 1.0 standard. This allows accounting software to automatically import your invoice data.

**Required CLI flag:** You must compile with PDF/A-3b support for the attachment to be valid:

```bash
typst compile --pdf-standard=a-3b invoice.typ
```

**Available profiles:**

| Profile       | Description                                                                                                                                          |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `auto`        | The richest profile the invoice satisfies: `"xrechnung"` for a buyer in Germany if all XRechnung rules are met, otherwise `"en16931"` (recommended). |
| `"minimum"`   | Header-only data (seller, buyer, date, total). No line items.                                                                                        |
| `"basic-wl"`  | Header + payment details. No line items.                                                                                                             |
| `"basic"`     | Full line items included.                                                                                                                            |
| `"en16931"`   | Full EN 16931 compliance with complete line-item data.                                                                                               |
| `"xrechnung"` | Identical to `"en16931"` but specifies full compliance with the German XRechnung 3.0 standard.                                                       |

:::info
With `zugferd: auto`, `invoice-pro` chooses the richest profile the invoice satisfies. For a buyer in Germany it tries XRechnung 3.0 and uses it if the invoice meets all XRechnung rules (for example, it needs the buyer reference or Leitweg-ID). Otherwise, and for buyers outside Germany, it uses `"en16931"`. The XRechnung rules that were not met are listed as warnings, which `zugferd-errors: "report"` shows, and the report names the chosen profile. An explicit profile is always used as given: `"en16931"` stays EN 16931 between German parties, too. Earlier versions switched it to XRechnung automatically; use `auto` for that now.
:::

**Example:**

```typst
#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "Musterfirma GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 123 456789",
      email: "max@musterfirma.de",
    ),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Kundenweg 5",
    city: "54321 Kundenstadt",
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "INV-2026-001",
)
```

For accurate UN/CEFACT unit codes in the embedded XML, use the dictionary form for `unit` on your line items — see the [Line Items API](../line-items/index.md#item) for details.

**Validation:** Before the XML is embedded, the invoice data is checked against the business rules of the profile. All problems are listed at once, each with the rule, the input to fix and a hint. With `zugferd-errors: "report"` they are shown in the document instead of stopping the compilation. See [Validation and Error Reporting](../../e-invoicing.md#validation-and-error-reporting) for details and the [E-Invoicing guide](../../e-invoicing.md#data-requirements-for-compliance) for the data each profile requires.

---

## Minimal Valid Configuration

While the `invoice` function offers many ways to customize your document, you only need to provide a few core parameters to generate a legally valid and functional invoice. At a bare minimum, you must define the sender, the recipient, a unique invoice number, and your tax identifier.

Here is an example of the minimal boilerplate needed to get started:

```typst
#import "@preview/invoice-pro:0.4.2": *

#show: invoice.with(
  sender: (
    name: "Max Mustermann",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acme Corporation",
    address: "Business Blvd 42",
    city: "54321 Metropolis",
  ),
  invoice-nr: "INV-2026-001",
)

// The document body starts here
#line-items[
  #item(
    [Consulting Services],
    quantity: 10,
    unit: "h",
    price: 150.00,
  )
]
```

:::tip
Notice that we didn't provide a `date` or `subject` parameter in the minimal example. If you leave these out, the package automatically defaults the date to today (`datetime.today()`) and infers a standard subject line (like "Invoice" or "Rechnung") based on your active locale.
:::
