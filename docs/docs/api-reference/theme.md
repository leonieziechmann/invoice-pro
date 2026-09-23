---
sidebar_position: 6
---

# Theming API

:::warning
**Unstable API**

The theming API is currently in a foundational state and is considered highly unstable. It will be fully finalized and locked in **v0.5.0**. Proceed with caution when building highly custom visual layouts, as breaking changes to the rendering pipeline are expected.
:::

The `invoice-pro` theming engine provides a **Cascading** approach to document styling. Themes control the visual layout, typographic choices, and structural positioning of the underlying **Normalized** data objects evaluated during the invoice compilation process.

Currently, the package ships with a `blank` theme for fully custom layouts and a standard `DIN-5008` implementation.

## The DIN-5008 Theme

The `DIN-5008` theme is the default implementation out-of-the-box. It constructs a business letter layout compliant with the German DIN 5008 standard, ensuring that recipient addresses align perfectly with standardized window envelopes.

:::info
By default, the theme is configured for Form A, but Form B can easily be selected via parameters.
:::

### Component Parameters

| Key              | Type              | Description                                                                                    |
| :--------------- | :---------------- | :--------------------------------------------------------------------------------------------- |
| `form`           | `str`             | Determines the letter form layout. Accepts `"A"` or `"B"`. Defaults to `"A"`.                  |
| `font`           | `str`             | The primary font family applied to the document. Defaults to `"Liberation Sans"`.              |
| `hole-mark`      | `bool`            | Toggles the rendering of the punch hole indicator mark on the left margin. Defaults to `true`. |
| `folding-marks`  | `bool`            | Toggles the rendering of folding marks on the left margin. Defaults to `true`.                 |
| `color-row-odd`  | `color` \| `none` | Background fill for odd line item rows (1st, 3rd, ...). Defaults to `none`.                    |
| `color-row-even` | `color` \| `none` | Background fill for even line item rows (2nd, 4th, ...). Defaults to `rgb("e2e8f0")`.          |
| `margin`         | `dictionary`      | Overrides the default document margins. Defaults to `(:)`.                                     |

:::info
The row fill is applied per **line item**, not per physical table row: description, discount, and subtotal rows always share the fill of the item they belong to, and page breaks do not shift the alternation. The table header and the totals block are not affected by these parameters.
:::

### Example Usage

```typst
#import "@preview/invoice-pro:0.4.2": invoice, themes

// Initialize the invoice with a customized DIN-5008 theme
#show: invoice.with(
  // We configure the theme function and pass it to the invoice
  theme: themes.DIN-5008(
    form: "B", // Form B pushes the address block further down
    font: "Arial", // Replacing the default Liberation Sans
    hole-mark: false, // Disabling the punch hole mark for digital-only PDFs
    color-row-even: none // Disabling the default row striping
  ),
  sender: (name: "Acme Corp"),
  recipient: (name: "Jane Doe"),
)

// Document body goes here
```

---

## The Blank Theme

The `blank` theme is the absolute barebones architectural primitive provided by the engine. It acts as an unstyled, empty canvas that applies zero visual formatting out-of-the-box. It maps directly to the internal base layout structure.

:::tip
**Document-Level Styling**

Because the `blank` theme applies strictly no document-level theming, the output of the [`invoice`](./invoice) function can be safely wrapped with standard native Typst styling rules. This allows you to define your page layout globally before initializing the invoice context.
:::

### Example Usage

```typst
#import "@preview/invoice-pro:0.4.2": invoice, themes

// 1. Apply native Typst document-level formatting
#set page("a5", margin: (left: 0.5cm, right: 4cm))

// 2. Initialize the invoice with the blank theme
#show: invoice.with(
  theme: themes.blank, // Bypasses internal layout styles
  sender: (:),
  recipient: (:),
)

// 3. Document body goes here
```

---

## Data for Custom Layouts

A theme consists of one layout function per component, which can be replaced with `.with(..)`, e.g. `themes.blank.with(bank-details: (ctx, view) => ..)`. The components prepare their data before they call the layout, so a layout only draws: it neither normalizes nor checks values. Like the rest of the theming API, these data are not stable yet.

### Bank Details

The `bank-details` layout, `(ctx, view) => content`, receives:

| Key                                         | Description                                                                                                                                                                                                                                     |
| :------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `view.sender.name`                          | The account holder: the `name` of `bank-details`, else the sender name on one line.                                                                                                                                                             |
| `view.sender.bank`                          | The name of the bank, `""` if not given.                                                                                                                                                                                                        |
| `view.sender.iban`                          | The IBAN without spaces and in upper case, `""` if missing. The built-in layout prints it in groups of four.                                                                                                                                    |
| `view.sender.iban-valid`                    | Whether the IBAN is valid. It is only `false` with `zugferd-errors: "report"`, otherwise an invalid IBAN stops the compilation.                                                                                                                 |
| `view.sender.bic`                           | The BIC without spaces and in upper case, `""` if not given.                                                                                                                                                                                    |
| `view.qr-code.size`, `view.qr-code.display` | The size of the QR code, and whether the bank details show one.                                                                                                                                                                                 |
| `view.qr-code.payload`                      | The EPC-QR code to draw: `beneficiary`, `iban`, `bic`, `amount`, `reference` and `text`, the arguments of `epc-qr-code` from the `sepay` package. `none` if no code is shown (it is hidden, or the currency is not EUR) or cannot be generated. |
| `view.qr-code.problems`                     | Why the EPC-QR code cannot be generated, as `(short: .., message: ..)`. Only with `zugferd-errors: "report"`, otherwise the compilation stops before the layout is called. The built-in layout shows a placeholder that names them.             |
| `view.reference`, `view.text`               | The payment reference, as structured reference or as text (at most one of them is set).                                                                                                                                                         |
| `view.show-reference`                       | Whether to print the payment reference.                                                                                                                                                                                                         |
| `view.report-problems`                      | Whether problems are shown in the document (`zugferd-errors: "report"`) instead of stopping the compilation.                                                                                                                                    |
| `view.payment-amount`                       | The amount to pay.                                                                                                                                                                                                                              |

### Exemption Notes

The `line-items` layout, `(ctx, data, body) => content`, receives the legal notes below the line items that give the reason for an exemption (exemption grounds, reverse charge, the small business clause) as `data.exemption-notes`, in the order to print them. Each note has these keys:

| Key      | Description                                                                                                                              |
| :------- | :--------------------------------------------------------------------------------------------------------------------------------------- |
| `kind`   | `"small-business"` for the clause of `tax-exempt-small-biz`, `"grounds"` for an exemption ground.                                        |
| `marker` | The marker (`"*"`, `"**"`, ...) that links the note to the VAT line of its category or to its items, `none` if neither of them shows it. |
| `body`   | The text of the note.                                                                                                                    |

The VAT lines carry the same markers (`marker` of each entry of `data.taxes`), as do the items of a VAT category with several exemption grounds (`tax.marker` of each entry of `data.items`). With exemption notes, the built-in layout leaves out the standard tax statement (e.g. "All items are excl. 19% Tax.").
