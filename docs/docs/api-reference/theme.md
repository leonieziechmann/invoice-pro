---
sidebar_position: 6
---

# Theming API

:::warning
**Unstable API**

The theming API is currently in a foundational state and is considered highly unstable. It will be fully finalized and locked in **v0.4**. Proceed with caution when building highly custom visual layouts, as breaking changes to the rendering pipeline are expected.
:::

The `invoice-pro` theming engine provides a **Cascading** approach to document styling. Themes control the visual layout, typographic choices, and structural positioning of the underlying **Normalized** data objects evaluated during the invoice compilation process.

Currently, the package ships with a `blank` theme for fully custom layouts and a standard `DIN-5008` implementation.

## The DIN-5008 Theme

The `DIN-5008` theme is the default implementation out-of-the-box. It constructs a business letter layout compliant with the German DIN 5008 standard, ensuring that recipient addresses align perfectly with standardized window envelopes.

:::info
By default, the theme is configured for Form A, but Form B can easily be selected via parameters.
:::

### Component Parameters

| Key             | Type         | Description                                                                                    |
| :-------------- | :----------- | :--------------------------------------------------------------------------------------------- |
| `form`          | `str`        | Determines the letter form layout. Accepts `"A"` or `"B"`. Defaults to `"A"`.                  |
| `font`          | `str`        | The primary font family applied to the document. Defaults to `"Liberation Sans"`.              |
| `hole-mark`     | `bool`       | Toggles the rendering of the punch hole indicator mark on the left margin. Defaults to `true`. |
| `folding-marks` | `bool`       | Toggles the rendering of folding marks on the left margin. Defaults to `true`.                 |
| `margin`        | `dictionary` | Overrides the default document margins. Defaults to `(:)`.                                     |

### Example Usage

```typst
#import "@preview/invoice-pro:0.3.0": invoice, themes

// Initialize the invoice with a customized DIN-5008 theme
#show: invoice.with(
  // We configure the theme function and pass it to the invoice
  theme: themes.DIN-5008(
    form: "B", // Form B pushes the address block further down
    font: "Arial", // Replacing the default Liberation Sans
    hole-mark: false // Disabling the punch hole mark for digital-only PDFs
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
#import "@preview/invoice-pro:0.3.0": invoice, themes

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
