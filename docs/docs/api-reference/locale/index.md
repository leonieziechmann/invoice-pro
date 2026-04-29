---
sidebar_position: 5
---

# Locale API

The locale system in `invoice-pro` is a powerful engine that dictates the language of your document, the formatting of dates and currencies, and the default tax rates and legal behaviors of your region.

By default, standard text (like "Invoice", "Subtotal", or "Tax") is automatically translated, and prices are formatted according to the regional standards.

---

## Predefined Locales

Locales are accessed via the `locale` module and are structured as `locale.<lang>-<region>`.

- **Language (`<lang>`)**: Determines the translations for all text strings.
- **Region (`<region>`)**: Determines currency symbols, date formats, number separators, and standard tax configurations.

### Available Combinations

| Language           | Regions                            | Example                                                                    |
| :----------------- | :--------------------------------- | :------------------------------------------------------------------------- |
| **`de`** (German)  | `at`, `ch`, `de`, `es`, `fr`, `it` | `locale.de-de` (German in Germany), `locale.de-ch` (German in Switzerland) |
| **`en`** (English) | `at`, `ch`, `de`, `es`, `fr`, `it` | `locale.en-de` (English text, German formatting/taxes)                     |
| **`fr`** (French)  | `at`, `ch`, `de`, `es`, `fr`, `it` | `locale.fr-ch` (French in Switzerland)                                     |
| **`it`** (Italian) | `at`, `ch`, `de`, `es`, `fr`, `it` | `locale.it-it` (Italian in Italy)                                          |
| **`es`** (Spanish) | `at`, `ch`, `de`, `es`, `fr`, `it` | `locale.es-es` (Spanish in Spain)                                          |

**Example usage in your document root:**

```typst
#show: invoice.with(
  locale: locale.en-de, // English language, German region
  // ...
)
```

---

## Customizing Locales

Sometimes you need to change a specific word (e.g., renaming "Invoice" to "Proforma Invoice") or tweak a currency symbol without creating a whole new locale from scratch.

Every predefined locale is actually a function that accepts overrides from the `locale.custom` module.

:::tip
You can pass multiple custom overrides into your locale function. Only the fields you explicitly define will be changed; the rest will fall back to the locale's default.
:::

```typst
#import "@preview/invoice-pro:0.1.0": invoice, locale

#show: invoice.with(
  locale: locale.en-de.with({
    import locale.custom: *

    document(invoice: "Proforma Invoice")
    line-items(position: "Pos.", unit-price: "Price/Unit")
  }),
  // ...
)
```

---

## The `locale.custom` Module API

The `locale.custom` module provides specialized functions to override specific groups of settings safely.

### Language Overrides (Text & Translations)

These functions allow you to change the text labels printed on the invoice.

| Function                         | Parameters                                                                                                                        | Description                                              |
| :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------- |
| `locale.custom.document(..)`     | `invoice`                                                                                                                         | Document titles (e.g., "Invoice", "Gutschrift").         |
| `locale.custom.address(..)`      | `recipient`, `sender`                                                                                                             | Labels above addresses.                                  |
| `locale.custom.reference(..)`    | `tax-number`, `invoice-number`                                                                                                    | Labels for the metadata header.                          |
| `locale.custom.line-items(..)`   | `position`, `description`, `quantity`, `unit-price`, `price`, `total`, `vat`, `net`, `gross`, `discount`, `surcharge`, `subtotal` | Column headers and specific terms inside the item table. |
| `locale.custom.summary(..)`      | `sum`, `vat-tax`, `total`, `including`, `excluding`                                                                               | Labels for the final calculation block.                  |
| `locale.custom.global-info(..)`  | `tax-statement`, `unit`, `quantity`, `date`                                                                                       | General statements below the table.                      |
| `locale.custom.bank-details(..)` | `account-holder`, `bank`, `iban`, `bic`, `reference`                                                                              | Labels for the bank details block.                       |
| `locale.custom.payment(..)`      | `text`, `deadline-date`, `deadline-days`, `deadline-soon`                                                                         | Text and deadline phrasing for the payment goal.         |
| `locale.custom.signature(..)`    | `closing`                                                                                                                         | The sign-off text (e.g., "Sincerely").                   |
| `locale.custom.legal(..)`        | `vat-exemption`                                                                                                                   | The legal notice for small business exemptions.          |

### Region Overrides (Formatting & Logic)

These functions interact with the underlying mathematical and regional formatting logic.

:::warning
Changing formatting functions or normalization logic requires providing custom Typst functions (e.g., `(number) => str`). Be careful when overriding these, as they affect the entire document's calculations and display.
:::

| Function                      | Parameters                                                       | Description                                                                                  |
| :---------------------------- | :--------------------------------------------------------------- | :------------------------------------------------------------------------------------------- |
| `locale.custom.format(..)`    | `percent`, `number`, `currency`, `currency-fine`, `date`, `time` | Functions determining how data types are converted to strings (e.g., changing `€` to `EUR`). |
| `locale.custom.normalize(..)` | `money`, `money-fine`, `infer-tax`                               | Functions controlling rounding logic and raw percentage inference.                           |
| `locale.custom.tax(..)`       | `default-vat`, `small-enterprise-special-scheme`                 | Overrides the default tax objects applied by this region.                                    |

### Example: Custom Currency Formatting

If you are using `locale.de-de` but want to display "EUR" instead of the "€" symbol, you can override the formatting functions:

```typst
#show: invoice.with(
  locale: locale.de-de.with(
    locale.custom.format(
      currency: (val) => str(calc.round(val, digits: 2)) + " EUR",
      currency-fine: (val) => str(val) + " EUR"
    )
  ),
  // ...
)
```
