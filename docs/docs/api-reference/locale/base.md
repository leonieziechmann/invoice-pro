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

| Key    | Type  | Description                                         |
| :----- | :---- | :-------------------------------------------------- |
| `lang` | `str` | The ISO 639-1 language code (e.g., `"en"`, `"de"`). |

### `document`

Designations for primary document types.

| Key       | Type  | Description                                               |
| :-------- | :---- | :-------------------------------------------------------- |
| `invoice` | `str` | The title used for standard invoices (e.g., `"Invoice"`). |

### `address`

Labels indicating the address blocks.

| Key         | Type  | Description                                            |
| :---------- | :---- | :----------------------------------------------------- |
| `recipient` | `str` | Label above the recipient address (e.g., `"Bill To"`). |
| `sender`    | `str` | Label above the sender details (e.g., `"From"`).       |

### `reference`

Designations for header metadata.

| Key              | Type  | Description                                                   |
| :--------------- | :---- | :------------------------------------------------------------ |
| `tax-number`     | `str` | Label for the sender's tax identification (e.g., `"Tax ID"`). |
| `invoice-number` | `str` | Label for the document identifier (e.g., `"Invoice Number"`). |

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

| Key             | Type                            | Description                                                                            |
| :-------------- | :------------------------------ | :------------------------------------------------------------------------------------- |
| `text`          | `(content, content) => content` | Generates the final payment instruction sentence. Parameters map to `(sum, deadline)`. |
| `deadline-date` | `(content) => content`          | Text generator for a fixed target date (e.g., `[no later than #date]`).                |
| `deadline-days` | `(int) => str`                  | Text generator for a relative target date (e.g., `[within #str(days) days]`).          |
| `deadline-soon` | `str`                           | Text for immediate/prompt payment.                                                     |

### `signature`

Greetings and the sign-off area.

| Key       | Type  | Description                               |
| :-------- | :---- | :---------------------------------------- |
| `closing` | `str` | The sign-off text (e.g., `"Sincerely,"`). |

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
| `region` | `str` | The official identifier or ISO code of the region (e.g., `"DE"`, `"US"`). |

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
#import "@preview/invoice-pro:0.3.0": invoice, locale

#let custom-lang = (
  payment: (
    // Update the prompt payment phrasing
    deadline-soon: "due immediately upon receipt",
  )
)

#show: invoice.with(
  locale: locale.build-locale(
    custom-lang,
    locale.region.en
  )
)
```

:::note
The `normalize.infer-tax` function is a vital bridge. Whenever a user types a raw percentage (e.g., `19%`) in their line items, this function converts it into a standardized tax object containing the correct **Grounds** and legal text specific to that region.
:::
