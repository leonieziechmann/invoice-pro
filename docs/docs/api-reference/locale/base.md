---
sidebar_position: 2
---

# Base Schema

When authoring custom locales or overriding specific fields, your provided dictionaries are evaluated against the internal `base-language` and `base-region` master schemas.

The engine utilizes a **Cascading** deep-merge strategy. Any key omitted in your custom locale will automatically fall back to the defaults defined in these schemas. This ensures that your invoice template always compiles safely, even if future updates introduce new fields or tax **Grounds**.

---

## Language Schema (`base-language`)

The language dictionary acts as the structural template for all translations. It contains exclusively linguistic strings, formatting text, and functions that assemble localized sentences.

:::info
All string fields within the language schema dictate the static text printed on the document. Functions within `payment` and `global-info` are used to syntactically structure dynamic values (like dates and amounts) according to regional grammar rules.
:::

### `meta`

Contains core metadata about the language configuration.

| Key    | Type  | Description                                                                                                                                      |
| :----- | :---- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| `lang` | `str` | The ISO 639-1 language code (e.g., `"en"`, `"de"`). Sets the document language (`text.lang`), which drives hyphenation and the PDF language tag. |

### `document`

Designations for the document types: the default titles of `invoice(document-type: ..)`.

| Key           | Type  | Description                                                                                                              |
| :------------ | :---- | :----------------------------------------------------------------------------------------------------------------------- |
| `invoice`     | `str` | The title used for standard invoices (e.g., `"Invoice"`).                                                                |
| `credit-note` | `str` | The title of a credit note (e.g., `"Credit Note"`, in German `"Rechnungskorrektur"`).                                    |
| `corrected`   | `str` | The title of a corrected invoice (e.g., `"Corrected Invoice"`).                                                          |
| `prepayment`  | `str` | The title of a prepayment invoice (e.g., `"Prepayment Invoice"`).                                                        |
| `self-billed` | `str` | The title of a self-billed invoice, the mention the law requires on it (e.g., `"Self-Billing Invoice"`, `"Gutschrift"`). |

### `address`

Labels indicating the address blocks.

| Key         | Type  | Description                                            |
| :---------- | :---- | :----------------------------------------------------- |
| `recipient` | `str` | Label above the recipient address (e.g., `"Bill To"`). |
| `sender`    | `str` | Label above the sender details (e.g., `"From"`).       |

### `reference`

Designations for header metadata.

| Key              | Type  | Description                                                                                           |
| :--------------- | :---- | :---------------------------------------------------------------------------------------------------- |
| `tax-number`     | `str` | Label for the sender's tax identification (e.g., `"Tax ID"`).                                         |
| `invoice-number` | `str` | Label for the document identifier (e.g., `"Invoice Number"`).                                         |
| `vat-id`         | `str` | Label for the Value Added Tax identifier (e.g., `"VAT ID"`).                                          |
| `invoice-date`   | `str` | Label for the date of the invoice (e.g., `"Invoice Date"`).                                           |
| `service-time`   | `str` | Label for the period of service (e.g., `"Period of Service"`).                                        |
| `payee`          | `str` | Label for who receives the payment instead of the sender, e.g. a factoring company (e.g., `"Payee"`). |

### `line-items`

Column headers and structural labels for the line-items table.

| Key           | Type  | Description                                           |
| :------------ | :---- | :---------------------------------------------------- |
| `position`    | `str` | Column header for the item position index.            |
| `description` | `str` | Column header for the item name or description.       |
| `quantity`    | `str` | Column header for the item amount.                    |
| `unit-price`  | `str` | Column header for the cost per unit.                  |
| `price`       | `str` | Column header for the base price.                     |
| `total`       | `str` | Column header for the final line amount.              |
| `vat`         | `str` | Column header for the applied tax/VAT rate.           |
| `net`         | `str` | Suffix or label indicating net amounts.               |
| `gross`       | `str` | Suffix or label indicating gross amounts.             |
| `discount`    | `str` | Label for applied discounts.                          |
| `surcharge`   | `str` | Label for applied surcharges.                         |
| `subtotal`    | `str` | Label indicating a running subtotal within the table. |
| `conjunction` | `str` | Word before the last name of a bundle description.    |
| `origin`      | `str` | Label of the country of origin of an item.            |

### `summary`

Labels for the calculation footer at the end of the table.

| Key         | Type  | Description                           |
| :---------- | :---- | :------------------------------------ |
| `sum`       | `str` | Label for the total sum before taxes. |
| `vat-tax`   | `str` | Label for the calculated tax amount.  |
| `total`     | `str` | Label for the final amount due.       |
| `including` | `str` | Short label for "inclusive of".       |
| `excluding` | `str` | Short label for "exclusive of".       |

### `global-info`

Static labels and dynamic text generators placed below the table.

| Key             | Type                                     | Description                                                                                        |
| :-------------- | :--------------------------------------- | :------------------------------------------------------------------------------------------------- |
| `tax-statement` | `(content, content, content) => content` | Sentence specifying the universal tax rate applied. Parameters map to `(tax-text, rate, vat-tax)`. |
| `unit`          | `str`                                    | Fallback text if a uniform unit applies to all items.                                              |
| `quantity`      | `str`                                    | Fallback text if a uniform quantity applies to all items.                                          |
| `date`          | `str`                                    | Fallback text if a uniform service date applies to all items.                                      |

### `tax-exemption`

Notes on why no VAT is charged, for the tax categories that need one. When no item of such a category gives its own `grounds`, the note is printed below the line items and written as exemption reason (BT-120) into the e-invoice.

| Key               | Type  | Description                                                                                       |
| :---------------- | :---- | :------------------------------------------------------------------------------------------------ |
| `reverse-charge`  | `str` | Reverse charge (`AE`), e.g. a `tax.new(category: "AE")` without grounds (e.g. "Reverse charge").  |
| `intra-community` | `str` | Intra-community supply (`K`), `tax.intra-community()` (e.g. "Tax-exempt intra-community supply"). |
| `export`          | `str` | Export outside the EU (`G`), `tax.export()` (e.g. "Tax-exempt export").                           |
| `outside-scope`   | `str` | Not subject to VAT (`O`), `tax.outside-scope()` (e.g. "Not subject to VAT").                      |

### `units`

Designations for common units of measure.

| Key            | Type  | Description                                               |
| :------------- | :---- | :-------------------------------------------------------- |
| `piece`        | `str` | Label for a singular item (e.g., `"piece"`).              |
| `set`          | `str` | Label for a set of items (e.g., `"set"`).                 |
| `pair`         | `str` | Label for a pair of items (e.g., `"pair"`).               |
| `lump-sum`     | `str` | Label for a lump-sum amount (e.g., `"lump sum"`).         |
| `hour`         | `str` | Label for hours of service (e.g., `"hour"`).              |
| `day`          | `str` | Label for days of service (e.g., `"day"`).                |
| `month`        | `str` | Label for monthly billing (e.g., `"month"`).              |
| `year`         | `str` | Label for yearly billing (e.g., `"year"`).                |
| `kilogram`     | `str` | Label for weight in kilograms (e.g., `"kilogram"`).       |
| `gram`         | `str` | Label for weight in grams (e.g., `"gram"`).               |
| `tonne`        | `str` | Label for weight in tonnes (e.g., `"tonne"`).             |
| `metre`        | `str` | Label for length in metres (e.g., `"metre"`).             |
| `square-metre` | `str` | Label for area in square metres (e.g., `"square metre"`). |
| `millimetre`   | `str` | Label for length in millimetres (e.g., `"millimetre"`).   |
| `centimetre`   | `str` | Label for length in centimetres (e.g., `"centimetre"`).   |
| `kilometre`    | `str` | Label for distance in kilometres (e.g., `"kilometre"`).   |
| `litre`        | `str` | Label for volume in litres (e.g., `"litre"`).             |
| `cubic-metre`  | `str` | Label for volume in cubic metres (e.g., `"cubic metre"`). |

### `bank-details`

Labels for the payment configuration block.

| Key              | Type  | Description                                      |
| :--------------- | :---- | :----------------------------------------------- |
| `account-holder` | `str` | Label for the owner of the bank account.         |
| `bank`           | `str` | Label for the financial institution.             |
| `iban`           | `str` | Label for the International Bank Account Number. |
| `bic`            | `str` | Label for the Bank Identifier Code.              |
| `reference`      | `str` | Label for the payment reference string.          |

### `payment-means`

Texts of the payment means besides the bank details: [`direct-debit`](../components.md#direct-debit), [`card-payment`](../components.md#card-payment) and [`paid`](../components.md#paid).

| Key                                                                                                              | Type                            | Description                                                                                                  |
| :--------------------------------------------------------------------------------------------------------------- | :------------------------------ | :----------------------------------------------------------------------------------------------------------- |
| `method`                                                                                                         | `str`                           | Label of the payment method (e.g., `"Payment method"`).                                                      |
| `transfer`, `direct-debit`, `sepa-direct-debit`, `card`, `credit-card`, `debit-card`, `cash`, `cheque`, `online` | `str`                           | Names of the payment methods (e.g., `"SEPA direct debit"`, `"Cash"`).                                        |
| `mandate`, `creditor-id`, `debtor-iban`                                                                          | `str`                           | Labels of the details of a direct debit (e.g., `"Mandate reference"`).                                       |
| `card-number`, `card-holder`                                                                                     | `str`                           | Labels of the details of a payment card (e.g., `"Card number"`).                                             |
| `paid`                                                                                                           | `(content, content) => content` | Sentence of a paid invoice. Parameters map to `(sum, date)`; `date` is `none` if not given.                  |
| `paid-due`                                                                                                       | `(content, content) => content` | Replaces `paid` when prepayments reduced the payable amount, so `sum` is the remaining amount that was paid. |

### `payment`

Text blocks and phrasing for payment terms.

| Key                                          | Type                             | Description                                                                                                                                                                                                                     |
| :------------------------------------------- | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `text`                                       | `(content, content) => content`  | Generates the final payment instruction sentence. Parameters map to `(sum, deadline)`.                                                                                                                                          |
| `text-due`                                   | `(content, content) => content`  | Replaces `text` when prepayments reduce the payable amount, so `sum` is the remaining amount due (e.g., `"the amount due"` instead of `"the total amount"`).                                                                    |
| `text-direct-debit`, `text-direct-debit-due` | `(content, content) => content`  | `text` and `text-due` when the amount is collected by [`direct-debit`](../components.md#direct-debit).                                                                                                                          |
| `text-card`, `text-card-due`                 | `(content, content) => content`  | `text` and `text-due` when the amount is charged to a [`card-payment`](../components.md#card-payment).                                                                                                                          |
| `cash-discount`                              | `(str, str, content) => content` | Note of a cash discount of the payment goal, printed after the payment sentence. Parameters map to `(percent, deadline, basis)`; `basis` is `none` if not given.                                                                |
| `deadline-date`                              | `(content) => content`           | Text generator for a fixed target date (e.g., `[no later than #date]`).                                                                                                                                                         |
| `deadline-days`                              | `(int) => str`                   | Text generator for a relative target date (e.g., `[within #str(days) days]`).                                                                                                                                                   |
| `deadline-soon`                              | `str`                            | Text for immediate/prompt payment.                                                                                                                                                                                              |
| `text-credit`                                | `(content, content) => content`  | Replaces `text` and `text-due`, and the sentences of a direct debit or a payment card, on a credit note or a self-billed invoice, whose sender pays the amount to the recipient (e.g., `"We will transfer the amount of ..."`). |
| `deadline-soon-credit`                       | `str`                            | Replaces `deadline-soon` in `text-credit` (e.g., `"promptly"`).                                                                                                                                                                 |

### `signature`

Greetings and the sign-off area.

| Key       | Type  | Description                               |
| :-------- | :---- | :---------------------------------------- |
| `closing` | `str` | The sign-off text (e.g., `"Sincerely,"`). |

### `legal`

Standard legal notices.

| Key             | Type  | Description                                                                                                                                                                                                            |
| :-------------- | :---- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vat-exemption` | `str` | The small business note in the invoice language. It is printed in front of the region's legal note when the language differs from the region, and alone when the region's scheme has no `grounds`, so it names no law. |

### `errors`

Warning messages utilized for incorrect template usage.

| Key               | Type  | Description                                             |
| :---------------- | :---- | :------------------------------------------------------ |
| `name-missing`    | `str` | Error when the primary name is omitted.                 |
| `address-missing` | `str` | Error when the street address is omitted.               |
| `city-missing`    | `str` | Error when the city/postal code is omitted.             |
| `ambiguous-tax`   | `str` | Error thrown during ambiguous 0% tax resolution.        |
| `invalid-tax`     | `str` | Error thrown when an unrecognized tax rate is provided. |

---

## Region Schema (`base-region`)

The region dictionary is responsible for mathematical logic and localized data representation. It dictates how dates are displayed, how currencies are formatted, and how tax structures behave.

:::danger
Exercise extreme caution when overriding functions in the `normalize` block. Returning invalid types or unhandled floats here can disrupt **Forward/Backward Calculation** algorithms, ultimately leading to invalid PDF generation or incorrect invoice totals.
:::

### `meta`

Contains core metadata about the region configuration.

| Key      | Type  | Description                                                               |
| :------- | :---- | :------------------------------------------------------------------------ |
| `region` | `str` | The internal, lower-case identifier of the region (e.g., `"de"`, `"us"`). |

### `currency`

Metadata for the primary currency used in the region. This is essential for structured data payloads like ZUGFeRD or EPC-QR codes.

| Key             | Type  | Description                                                                      |
| :-------------- | :---- | :------------------------------------------------------------------------------- |
| `code`          | `str` | The 3-letter ISO 4217 currency code (e.g., `"EUR"`, `"CHF"`).                    |
| `symbol`        | `str` | The visual symbol of the currency (e.g., `"€"`, `"CHF "`).                       |
| `decimals`      | `int` | The standard number of subunits/decimal places for financial totals (e.g., `2`). |
| `decimals-fine` | `int` | The allowed number of decimal places for singular unit prices (usually `4`).     |

The currency formatters (`format.currency`, `format.currency-fine`) and the rounding (`normalize.money`, `normalize.money-fine`) derive from it. If a region or an override sets the `currency` without these functions, they are rebuilt from it, so the printed amounts always show the currency whose `code` the e-invoice states (BT-5):

```typst
#import "@preview/invoice-pro:0.4.2": invoice, locale

#show: invoice.with(
  // Prints "1.234,50 $" and states USD in the e-invoice
  locale: locale.de-de.with((region: (currency: (code: "USD", symbol: "$")))),
)
```

:::tip
To invoice in another currency with any locale, `currency` on the invoice is enough: `invoice(currency: "USD")` sets the code, the symbol and the decimals of the currency in the same way. Override the `currency` of the region only for a symbol or decimals of your own.
:::

### `normalize`

Functions mapping raw inputs to **Normalized** values.

| Key          | Type               | Description                                                                                                          |
| :----------- | :----------------- | :------------------------------------------------------------------------------------------------------------------- |
| `money`      | `number => number` | Rounds a numerical value to the standard decimal precision of the region's currency.                                 |
| `money-fine` | `number => number` | Rounds a value to a higher precision required for specific unit prices (e.g., fuel).                                 |
| `infer-tax`  | `ratio => tax`     | Interprets a raw tax value and maps it to a structured regional tax object containing appropriate [Grounds](../tax). |

### `format`

Functions responsible for converting data types into localized strings.

| Key             | Type                                        | Description                                                                           |
| :-------------- | :------------------------------------------ | :------------------------------------------------------------------------------------ |
| `percent`       | `(ratio \| number) => str`                  | Converts a ratio or number into a localized percentage string.                        |
| `number`        | `number => str`                             | Formats a number with regional thousands and decimal separators.                      |
| `currency`      | `number => str`                             | Formats a value as a currency string with the regional symbol and standard placement. |
| `currency-fine` | `number => str`                             | High-precision currency formatting used when unit prices require extra decimals.      |
| `date`          | `(datetime \| (datetime, datetime)) => str` | Formats a single date or an array defining a date range into a human-readable string. |
| `time`          | `datetime => str`                           | Formats a time object into a localized string (e.g., 24h or AM/PM).                   |

The regions build `number`, `currency` and `currency-fine` with `make-formatters` (from `utils/format.typ`), which also adds `currency-formatters`: a function that builds `currency` and `currency-fine` with the same number format for another `currency` dictionary. The locale factory uses it when an override changes the currency alone.

### `tax`

Contains default standard tax objects utilized by the region.

| Key                               | Type  | Description                                                                                                                                                                                                                                                                                                            |
| :-------------------------------- | :---- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default-vat`                     | `tax` | The standard VAT/Sales Tax rate applied when no specific rate is provided.                                                                                                                                                                                                                                             |
| `small-enterprise-special-scheme` | `tax` | The tax of small businesses (`tax-exempt-small-biz: true`). Its `grounds` are the printed legal note and the exemption reason (BT-120) of the e-invoice. Use `tax.exempt(grounds: ..)` (category E) where the law exempts small businesses and `tax.outside-scope(grounds: ..)` (O) where they are not liable for VAT. |

---

## Example: Schema Inspection and Override

When building your own tools or customizing a layout, you can leverage the cascading merge by specifying only the nested keys you wish to alter.

```typst
#import "@preview/invoice-pro:0.4.2": invoice, locale

#let custom-lang = (
  payment: (
    // Update the prompt payment phrasing
    deadline-soon: "due immediately upon receipt",
  )
)

#show: invoice.with(
  locale: locale.build-locale(
    custom-lang,
    locale.region.de
  )
)
```

:::note
The `normalize.infer-tax` function is a vital bridge. Whenever a user types a raw percentage (e.g., `19%`) in their line items, this function converts it into a standardized tax object containing the correct **Grounds** and legal text specific to that region.
:::
