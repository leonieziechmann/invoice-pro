---
sidebar_position: 1
---

# Invoice API

The `invoice` function is the main entry point of the `invoice-pro` package. It sets up the page layout, visual theme, localization settings, and the global tax configuration for the entire document.

:::info
Every invoice document must start with a `#show: invoice.with(..)` rule. All other components, such as `line-items` or [`payment-goal`](./components#payment-goal), must be placed **after** this show rule.

If you forget the show rule, your components will remain invisible because they rely on the underlying `loom` state engine to render properly.
:::

---

## `invoice`

Initializes the document and orchestrates the data calculation passes.

| Key                    | Type                                        | Description                                                                                                                                                        |
| :--------------------- | :------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `theme`                | `function`                                  | The visual theme to apply to the invoice. See [Themes](#theme) below.                                                                                              |
| `locale`               | `function`                                  | The locale settings for language and number formatting. See [Locales](#locale) below.                                                                              |
| `sender`               | `dictionary`                                | Sender details (e.g., name, address, contact info).                                                                                                                |
| `recipient`            | `dictionary`                                | Recipient details (e.g., name, address, customer ID).                                                                                                              |
| `date`                 | `datetime`                                  | The date of the invoice. Defaults to `datetime.today()`.                                                                                                           |
| `subject`              | `str` \| `content` \| `auto`                | The subject line of the invoice. If `auto`, it is inferred from the [locale](./locale) (e.g., "Rechnung" in German).                                               |
| `references`           | `none` \| `dictionary` \| `array`           | Reference information for the document header (e.g., customer number, order date). Accepts a dictionary of key-value pairs or an array of `(label, value)` tuples. |
| `invoice-nr`           | `none` \| `str` \| `content`                | The unique identifier or number of the invoice.                                                                                                                    |
| `tax-nr`               | `none` \| `str` \| `content`                | Your company's unique tax identifier / VAT ID.                                                                                                                     |
| `tax`                  | `auto` \| `ratio` \| `dictionary` \| `none` | The default tax rate for the document. See [Tax](#tax--tax-exempt-small-biz) below.                                                                                |
| `tax-mode`             | `"exclusive"` \| `"inclusive"`              | Sets the global baseline for tax calculation. `"exclusive"` treats standard prices as net. `"inclusive"` treats standard prices as gross.                          |
| `tax-exempt-small-biz` | `bool`                                      | If `true`, applies the small business tax exemption logic based on the selected locale.                                                                            |
| `body`                 | `content`                                   | The content of the invoice, containing your containing your [`line-items`](./line-items) and other layout components.                                              |

## Key Parameters Explained

While the table above lists all available options, a few parameters dictate the core behavior, layout, and legal compliance of your invoice:

### `sender` & `recipient`

These parameters define the contact details for the invoicing party (sender) and the customer (recipient). Both parameters accept a standard dictionary.

Standard keys generally include `name`, `street`, and `city`. Additionally, you can use the `extras` key to provide arbitrary supplementary information (like phone numbers, email addresses, or commercial register numbers) styled according to your theme.

Just like the header `references`, the `extras` field accepts either a dictionary of key-value pairs or an array of `(label, value)` tuples.

**Example:**

```typst
sender: (
  name: "Max Mustermann",
  street: "Musterstraße 1",
  city: "12345 Musterstadt",
  extras: (
    "Phone": "+49 123 456789",
    "Email": "max@mustermann.de",
    "Web": "www.mustermann.de"
  )
),
recipient: (
  name: "Acme Corporation",
  street: "Business Blvd 42",
  city: "54321 Metropolis",
  extras: (
    ("Contact Person", "Jane Doe"),
    ("Department", "Accounting")
  )
)
```

### `locale`

The locale system dictates the language of standard text (like "Invoice" or "Subtotal"), currency formatting, and the default tax rates for your region.

Locales are structured as `locale.<lang>-<region>`.

- **Available Languages (`<lang>`)**: `de` (German), `en` (English), `fr` (French), `it` (Italian), `es` (Spanish).
- **Available Regions (`<region>`)**: `de` (Germany), `at` (Austria), `ch` (Switzerland), `fr` (France), `it` (Italy), `es` (Spain).

**Example:** `locale: locale.en-de` (English language formatting, but German regional tax defaults).

_See the [Locale API Reference](./locale) for the full list and customization options._

### `theme`

The theme dictates the visual layout and styling of your invoice. You must pass a theme function from the `themes` module.

:::note
The theming engine is currently undergoing expansion. At the moment, there are two primary themes available:

- `themes.DIN-5008()`: A standard German business letter layout.
- `themes.base`: A minimal, bare-bones layout.
  :::

_See the [Theme API Reference](./theme) for more details._

### `tax` & `tax-exempt-small-biz`

By default (when `tax` is set to `auto`), the system fetches the standard VAT/GST rate from your selected `locale` region. However, you can explicitly override this default at the document root by providing a simple percentage (e.g., `19%`) or using a specialized code from the `tax` module (e.g., `tax.vat(21%)`).

If you run a small business that is exempt from charging VAT (e.g., the _Kleinunternehmerregelung_ in Germany), you can simply set `tax-exempt-small-biz: true`.

:::note
If you enable the small business exemption, the system automatically applies the correct legal tax code and 0% rate for your region. Therefore, you should leave the `tax` parameter set to `auto`. If you manually set a custom `tax` rate while `tax-exempt-small-biz` is `true`, the compiler will throw an error to prevent conflicting configurations.
:::

_See the [Tax Module API Reference](./tax) for a detailed breakdown of all available tax codes and margin schemes._

### `references`

The `references` parameter allows you to add custom metadata to the information block of the invoice (usually positioned in the top-right corner near the date and invoice number). This is the perfect place for Customer IDs, Order Dates, or Delivery Numbers.

You can provide this data in two formats:

- **As a Dictionary:** The simplest method for key-value pairs.
  ```typst
  references: (
    "Customer No.": "C-9982",
    "Order Date": "2026-04-10"
  )
  ```
- **As an Array of Tuples:** Dictionaries in Typst do not always guarantee a specific order. If the exact visual order of your reference fields is strictly required, use an array of `(label, value)` pairs instead.
  ```typst
  references: (
    ("Customer No.", "C-9982"),
    ("Order Date", "2026-04-10")
  )
  ```

---

## Minimal Valid Configuration

While the `invoice` function offers many ways to customize your document, you only need to provide a few core parameters to generate a legally valid and functional invoice. At a bare minimum, you must define the sender, the recipient, a unique invoice number, and your tax identifier.

Here is an example of the minimal boilerplate needed to get started:

```typst
#import "@preview/invoice-pro:0.3.0": *

#show: invoice.with(
  sender: (
    name: "Max Mustermann",
    street: "Musterstraße 1",
    city: "12345 Musterstadt",
  ),
  recipient: (
    name: "Acme Corporation",
    street: "Business Blvd 42",
    city: "54321 Metropolis",
  ),
  invoice-nr: "INV-2026-001",
  tax-nr: "DE123456789",
)

// The document body starts here
#line-items[
  #item(
    name: "Consulting Services",
    quantity: 10,
    unit: "h",
    price: 150.00
  )
]
```

:::tip
Notice that we didn't provide a `date` or `subject` parameter in the minimal example. If you leave these out, the package automatically defaults the date to today (`datetime.today()`) and infers a standard subject line (like "Invoice" or "Rechnung") based on your active locale.
:::
