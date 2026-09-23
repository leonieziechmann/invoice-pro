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

| Key              | Type                   | Description                                                                                                                                      |
| :--------------- | :--------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| `lang`           | `str`                  | The ISO 639-1 language code (e.g., `"en"`, `"de"`). Sets the document language (`text.lang`), which drives hyphenation and the PDF language tag. |
| `resolve-plural` | `(any, number) => any` | Picks the singular or plural form of a unit for a quantity.                                                                                      |

### `document`

Designations for primary document types.

| Key            | Type                    | Description                                                                   |
| :------------- | :---------------------- | :---------------------------------------------------------------------------- |
| `invoice`      | `str`                   | The title used for standard invoices (e.g., `"Invoice"`).                     |
| `page`         | `(int, int) => content` | The page label of the `page-number` part (e.g., `[Page #current of #total]`). |
| `continued-on` | `(int) => content`      | A note on a page whose content continues (e.g., `[Continued on page #page]`). |

### `address`

Labels indicating the address blocks.

| Key         | Type  | Description                                            |
| :---------- | :---- | :----------------------------------------------------- |
| `recipient` | `str` | Label above the recipient address (e.g., `"Bill To"`). |
| `sender`    | `str` | Label above the sender details (e.g., `"From"`).       |

### `sections`

Section headings a theme may print (provisional). Themes never hard-code their own labels, so every preset follows these strings.

| Key            | Type  | Description                                                 |
| :------------- | :---- | :---------------------------------------------------------- |
| `details`      | `str` | Heading of the invoice details (e.g., `"Invoice details"`). |
| `payment`      | `str` | Heading of the payment block (e.g., `"Payment"`).           |
| `bank-details` | `str` | Heading of the bank details (e.g., `"Bank details"`).       |
| `how-to-pay`   | `str` | Heading of a payment card (e.g., `"How to pay"`).           |

### `reference`

Designations for header metadata.

| Key                                                                                                                                                                                                                                                                                                                       | Type  | Description                                                    |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---- | :------------------------------------------------------------- |
| `tax-number`                                                                                                                                                                                                                                                                                                              | `str` | Label for the sender's tax identification (e.g., `"Tax ID"`).  |
| `invoice-number`                                                                                                                                                                                                                                                                                                          | `str` | Label for the document identifier (e.g., `"Invoice Number"`).  |
| `vat-id`                                                                                                                                                                                                                                                                                                                  | `str` | Label for the Value Added Tax identifier (e.g., `"VAT ID"`).   |
| `invoice-date`                                                                                                                                                                                                                                                                                                            | `str` | Label for the date of the invoice (e.g., `"Invoice Date"`).    |
| `service-time`                                                                                                                                                                                                                                                                                                            | `str` | Label for the period of service (e.g., `"Period of Service"`). |
| `customer-number`, `buyer-reference`, `recipient-vat-id`, `recipient-tax-number`, `order-number`, `order-date`, `project`, `contract-number`, `quote-number`, `delivery-note-number`, `delivery-address`, `preceding-invoice-number`, `due-date`, `payment-reference`, `contact-person`, `contact-phone`, `contact-email` | `str` | Labels of the [reference](../invoice/references.md) builders.  |

### `line-items`

Column headers and structural labels for the line-items table.

| Key           | Type  | Description                                           |
| :------------ | :---- | :---------------------------------------------------- |
| `position`    | `str` | Column header for the item position index.            |
| `item-id`     | `str` | Column header for the seller's item number.           |
| `unit`        | `str` | Column header for the unit.                           |
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
| `prepayment`  | `str` | Label for a prepayment line.                          |

### `summary`

Labels for the calculation footer at the end of the table.

| Key          | Type  | Description                                 |
| :----------- | :---- | :------------------------------------------ |
| `sum`        | `str` | Label for the total sum before taxes.       |
| `vat-tax`    | `str` | Label for the calculated tax amount.        |
| `total`      | `str` | Label for the final amount due.             |
| `including`  | `str` | Short label for "inclusive of".             |
| `excluding`  | `str` | Short label for "exclusive of".             |
| `prepayment` | `str` | Label for a prepayment in the totals.       |
| `amount-due` | `str` | Label for the amount due after prepayments. |

### `global-info`

Static labels and dynamic text generators placed below the table.

| Key             | Type                                     | Description                                                                                        |
| :-------------- | :--------------------------------------- | :------------------------------------------------------------------------------------------------- |
| `tax-statement` | `(content, content, content) => content` | Sentence specifying the universal tax rate applied. Parameters map to `(tax-text, rate, vat-tax)`. |
| `unit`          | `str`                                    | Fallback text if a uniform unit applies to all items.                                              |
| `quantity`      | `str`                                    | Fallback text if a uniform quantity applies to all items.                                          |
| `date`          | `str`                                    | Fallback text if a uniform service date applies to all items.                                      |

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

### `payment`

Text blocks and phrasing for payment terms.

| Key             | Type                            | Description                                                                                                                                                  |
| :-------------- | :------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `text`          | `(content, content) => content` | Generates the final payment instruction sentence. Parameters map to `(sum, deadline)`.                                                                       |
| `text-due`      | `(content, content) => content` | Replaces `text` when prepayments reduce the payable amount, so `sum` is the remaining amount due (e.g., `"the amount due"` instead of `"the total amount"`). |
| `deadline-date` | `(content) => content`          | Text generator for a fixed target date (e.g., `[no later than #date]`).                                                                                      |
| `deadline-days` | `(int) => str`                  | Text generator for a relative target date (e.g., `[within #str(days) days]`).                                                                                |
| `deadline-soon` | `str`                           | Text for immediate/prompt payment.                                                                                                                           |

### `signature`

Greetings and the sign-off area.

| Key       | Type  | Description                                                                  |
| :-------- | :---- | :--------------------------------------------------------------------------- |
| `closing` | `str` | The sign-off text (e.g., `"Sincerely,"`).                                    |
| `thanks`  | `str` | A closing thanks some themes print (e.g., `"Thank you for your business."`). |

### `legal`

Standard legal notices.

| Key             | Type  | Description                                                                 |
| :-------------- | :---- | :-------------------------------------------------------------------------- |
| `vat-exemption` | `str` | The legal notice for small business exemptions or zero-rated tax scenarios. |

### `errors`

Warning messages utilized for incorrect template usage.

| Key               | Type  | Description                                             |
| :---------------- | :---- | :------------------------------------------------------ |
| `name-missing`    | `str` | Error when the primary name is omitted.                 |
| `address-missing` | `str` | Error when the street address is omitted.               |
| `city-missing`    | `str` | Error when the city/postal code is omitted.             |
| `ambiguous-tax`   | `str` | Error thrown during ambiguous 0% tax resolution.        |
| `invalid-tax`     | `str` | Error thrown when an unrecognized tax rate is provided. |

### `validation`

The feedback of [`validation: "draft"`](../invoice/validation.md): inline markers, the page badge, the watermark and the report page. The messages of `validation: "strict"` stay in English.

| Key                                     | Type                   | Description                                                                                                                           |
| :-------------------------------------- | :--------------------- | :------------------------------------------------------------------------------------------------------------------------------------ |
| `marker`                                | `(content) => content` | The inline marker in place of a missing field (e.g., `[‹missing: #field›]`).                                                          |
| `missing`                               | `(content) => content` | The problem text of a missing field in the report.                                                                                    |
| `part-empty`                            | `(str) => content`     | The marker in place of a required part that rendered nothing.                                                                         |
| `badge`                                 | `(int) => str`         | The page badge (e.g., `"DRAFT · 2 problems"`).                                                                                        |
| `watermark`                             | `str`                  | The watermark word.                                                                                                                   |
| `e-invoice-short`                       | `str`                  | Added to the badge when the e-invoice XML was withheld.                                                                               |
| `report-title`                          | `str`                  | Heading of the report page.                                                                                                           |
| `report-intro`                          | `(int) => content`     | First paragraph of the report.                                                                                                        |
| `report-strict`                         | `content`              | The closing note on `validation: "strict"`.                                                                                           |
| `e-invoice-withheld`                    | `(str) => content`     | The notice when the XML was withheld; the parameter is the profile.                                                                   |
| `number`, `problem`, `reference`, `fix` | `str`                  | Column headers and the label of the fix.                                                                                              |
| `fix-or`                                | `str`                  | Joins two alternative fixes (e.g., `"or"`).                                                                                           |
| `classes`                               | `dictionary`           | Labels of the issue classes `data`, `e-invoice`, `theme` and `lint`.                                                                  |
| `fields`                                | `dictionary`           | Labels of the checked fields, keyed by field id (e.g., `invoice-number`, `recipient-address`).                                        |
| `issues`                                | `dictionary`           | Report texts of the theme and lint issues, each a function of the issue's arguments. A missing key falls back to the English message. |
| `roles`                                 | `dictionary`           | What each required role carries (`title`, `recipient`, `supplier`, `tax-id`).                                                         |

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

### `tax`

Contains default standard tax objects utilized by the region.

| Key                               | Type  | Description                                                                  |
| :-------------------------------- | :---- | :--------------------------------------------------------------------------- |
| `default-vat`                     | `tax` | The standard VAT/Sales Tax rate applied when no specific rate is provided.   |
| `small-enterprise-special-scheme` | `tax` | The legal tax object used for small businesses or special exemption schemes. |

---

## Example: Schema Inspection and Override

When building your own tools or customizing a layout, you can leverage the cascading merge by specifying only the nested keys you wish to alter.

```typst
#import "@preview/invoice-pro:0.4.2": invoice, locale

#let custom-lang = (
  payment: (
    // Update the prompt payment phrasing
    deadline-soon: "due immediately upon receipt",
  ),
)

#show: invoice.with(
  locale: locale.build-locale(
    custom-lang,
    locale.region.de, // German formatting and taxes
  ),
  // ...
)
```

`build-locale` takes a language dictionary and a region builder from `locale.region` (`at`, `ch`, `de`, `es`, `fr`, `it`). Keys missing from `custom-lang` fall back to the English base schema.

:::note
The `normalize.infer-tax` function is a vital bridge. Whenever a user types a raw percentage (e.g., `19%`) in their line items, this function converts it into a standardized tax object containing the correct **Grounds** and legal text specific to that region.
:::
