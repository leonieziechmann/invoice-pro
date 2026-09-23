---
sidebar_position: 6
---

# Theming API

A theme decides how an invoice looks: the page master (paper, envelope window, letterhead and footer zones), the brand (colors, fonts, logo) and the style of every block (table, totals, bank details). It never decides what the invoice says. The data comes from [`invoice`](../invoice/index.md) and the components, and the compliance output (PDF metadata, the ZUGFeRD XML, legal notes, the EPC-QR payload) is produced by the core, where no theme can drop it.

:::info
The theming API was redesigned in v0.5.0: `themes.DIN-5008` and `themes.blank` are gone. The [migration guide](./migration.md) maps every 0.4 parameter to its replacement.
:::

## Quick Start

A theme is a **lazy value**, like a locale. Pass it uncalled and customize it with `.with(..)`:

```typst
#import "@preview/invoice-pro:0.4.2": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(
      color: rgb("#0f766e"),
      logo: image("logo.svg", alt: "Studio Lina Berg"),
    ),
    theme.custom.marks(none), // digital only: no fold and punch marks
  ),
  locale: locale.de-de,
  sender: (
    name: "Studio Lina Berg",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "2026-0142",
)

#line-items[
  #item([Corporate design concept], price: 1800)
  #item([Logo artwork], price: 650)
]

#payment-terms(days: 14)
```

`theme.classic` is the default: `invoice` uses it when you pass no theme. The brand color is a seed. The table stripes, the text color on filled areas and the brand color used as text are derived from it, so they follow when you change it.

## Mental Model

| Concept    | What it is                                                                                                             | Written as                                       |
| :--------- | :--------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------- |
| **Layout** | The page master as data: paper, margins, marks, stationery, envelopes and named areas.                                 | `theme.layout.din-5008-a` or your own dictionary |
| **Area**   | A region of the page (a fixed box, a block in the flow, the header, the footer or a layer) that hosts parts.           | `theme.custom.area(..)`                          |
| **Part**   | A renderer `(ctx, view) => content` for one piece of output, such as `recipient`, `title` or `totals`.                 | `theme.custom.part(..)`, `theme.custom.wrap(..)` |
| **Token**  | One of 30 design decisions (colors, fonts, sizes, weights, strokes, spacing, radii) that every built-in part reads.    | `theme.custom.colors(..)`, `fonts(..)`, …        |
| **Option** | A setting of one built-in part, such as `items-table.zebra` or `totals.fill`.                                          | `theme.custom.items-table(..)`, …                |
| **Patch**  | A change to any of the above, usually built by a `theme.custom` helper and passed as a positional argument of `.with`. | `theme.classic.with(patch, patch, ..)`           |

A **preset** such as `theme.classic` is a _look_ (patches for tokens, options, parts and the style of areas) on a _default layout_. Looks never change geometry, so every preset works on every layout.

### Customization Ladder

| Step | What you do                                                          | Example                                                                                                                             |
| :--- | :------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| 1    | Pick a preset.                                                       | `theme.elegant`                                                                                                                     |
| 2    | Apply your brand.                                                    | `.with(theme.custom.brand(color: .., logo: ..))` ([Customization](./customization.md#brand))                                        |
| 3    | Pick another page master, drop the marks, print on letterhead paper. | `.with(layout: theme.layout.din-5008-b)`, `marks(none)`, `stationery(..)` ([Layouts](./layouts.md))                                 |
| 4    | Move parts between areas.                                            | `area("letterhead", parts: ("sender", "logo"))` ([Areas](./layouts.md#areas))                                                       |
| 5    | Restyle or replace one part.                                         | `wrap("totals", ..)`, `part("payment-terms", ..)` ([Parts](./parts.md))                                                             |
| 6    | Write your own page master.                                          | a layout dictionary with your own areas and prefixed custom parts ([Writing your own format](./layouts.md#writing-your-own-format)) |

### Precedence

A theme is folded from layers. A later layer wins over an earlier one.

| Layer | Source                                                                             | Scope              |
| :---- | :--------------------------------------------------------------------------------- | :----------------- |
| 1     | Schema defaults                                                                    | document           |
| 2     | The layout: `layout:` or the preset's default for the sender's country             | document           |
| 3     | The preset's look                                                                  | document           |
| 4     | Your patches, in the order of the `.with(..)` arguments; a chained `.with` appends | document           |
| 5     | [`themed(..)[..]`](./parts.md#scoped-overrides-themed) scopes, the innermost wins  | a part of the body |
| 6     | Explicit component arguments, such as `bank-details(qr-code: (display: false))`    | one component      |

Layout patches (`area`, `page`, `marks`, …) always apply to the final layout, wherever they appear in the chain. Native Typst rules in the body win over theme rules. Rules placed **before** `#show: invoice` lose: the theme sets the page, the font and the text size itself.

## Presets

Ten presets ship. `classic` and `plain` are frozen. The other eight keep their names and default layout families, but their appearance may still change in a minor release.

| Preset            | For                                              | Look                                                                                                     | Default layout (DE / US)                 |
| :---------------- | :----------------------------------------------- | :------------------------------------------------------------------------------------------------------- | :--------------------------------------- |
| `theme.classic`   | everyone; the default                            | Business letter with legal footer, continuation header on following pages and "Page 1 of 2".             | by region: `din-5008-a` / `us-letter-10` |
| `theme.plain`     | own letterhead paper, flow-only output           | The classic look without furniture: sender, title and recipient in the flow, registration in the footer. | `plain` on A4 / Letter                   |
| `theme.corporate` | larger companies, PO-driven B2B                  | Two colors, a brand rail with all legal data, filled table header, payable bar, serif display title.     | `a4-sidebar` / `us-letter-sidebar`       |
| `theme.elegant`   | law firms, notaries, tax advisers, consultancies | Serif letter: centered letterhead, ink blue, hairlines, no fills.                                        | `din-5008-b` / `us-letter-10`            |
| `theme.prestige`  | premium brands, hotels, fine dining              | Full-bleed onyx band with champagne type, serif display title; digital first.                            | `a4-band` / `us-letter-band`             |
| `theme.bold`      | agencies and studios                             | Poster block in the brand color with the document word and the amount due, mono labels, heavy rules.     | `a4-digital` / `us-letter-digital`       |
| `theme.technical` | IT freelancers, software houses, engineering     | Spec sheet: mono labels and figures, fine rule grid, section markers, inverted payable amount.           | `a4-digital` / `us-letter-digital`       |
| `theme.soft`      | cafés, practices, small retail, B2C              | Serif headings, rounded cards, number and date in pills, a "how to pay" card.                            | `a4-digital` / `us-letter-digital`       |
| `theme.compact`   | wholesale and distribution, long invoices        | 8.5 pt, item number and unit columns, filled repeating header, boxed totals.                             | `a4-dense` / `us-letter-dense`           |
| `theme.boxed`     | trades and crafts, print and fax                 | Ruled form boxes, heavy title, mono form labels; no fill carries meaning.                                | by region: `din-5008-a` / `us-letter-10` |

The default layout follows the sender's country (`layout: auto`); see [Layout by region](./layouts.md#layout-by-region). `elegant` uses DIN 5008 form B where the region rule picks form A, because its centered letterhead needs the taller zone.

### Gallery

All ten presets on identical data (same body, brand color and logo), page 1, each on its default layout for a German sender:

![The ten presets on identical data](/img/themes/fig-presets.png)

Each preset with sample data from the kind of business it is designed for, page 1:

|                                                            |                                                      |
| :--------------------------------------------------------: | :--------------------------------------------------: |
|    ![classic](/img/themes/preset-classic.png) `classic`    |    ![plain](/img/themes/preset-plain.png) `plain`    |
| ![corporate](/img/themes/preset-corporate.png) `corporate` | ![elegant](/img/themes/preset-elegant.png) `elegant` |
|  ![prestige](/img/themes/preset-prestige.png) `prestige`   |     ![bold](/img/themes/preset-bold.png) `bold`      |
| ![technical](/img/themes/preset-technical.png) `technical` |     ![soft](/img/themes/preset-soft.png) `soft`      |
|    ![compact](/img/themes/preset-compact.png) `compact`    |    ![boxed](/img/themes/preset-boxed.png) `boxed`    |

### Fonts

Typst packages cannot ship fonts, and Typst embeds only Libertinus Serif, New Computer Modern and DejaVu Sans Mono. Every font chain of every preset therefore ends in an embedded family, so each preset renders on any machine. Install the preferred family to get the intended look.

| Preset             | Preferred fonts (the embedded fallback in brackets)                                        |
| :----------------- | :----------------------------------------------------------------------------------------- |
| `classic`, `plain` | Liberation Sans (Libertinus Serif)                                                         |
| `corporate`        | Liberation Sans (Libertinus Serif); headings in Libertinus Serif                           |
| `elegant`          | Libertinus Serif (embedded)                                                                |
| `prestige`         | EB Garamond; headings in Playfair Display or Bodoni Moda (Libertinus Serif)                |
| `bold`             | Inter, Arial or Liberation Sans (Libertinus Serif); labels in DejaVu Sans Mono             |
| `technical`        | Inter, Liberation Sans or Arial (Libertinus Serif); labels and figures in DejaVu Sans Mono |
| `soft`             | Segoe UI or Liberation Sans (Libertinus Serif); headings in Libertinus Serif               |
| `compact`          | Inter, Arial or Liberation Sans (Libertinus Serif)                                         |
| `boxed`            | Liberation Sans (Libertinus Serif); labels in DejaVu Sans Mono                             |

When you set your own fonts, end the chain in an embedded family as well, for example `("Inter", "Liberation Sans", "Libertinus Serif")`.

## Passing a Theme

A theme is a function that `invoice` calls with the running package version's schema and the document environment. You only ever pass it along, uncalled or configured with `.with(..)`:

```typst
#let a = theme.classic // the default
#let b = theme.classic.with(layout: theme.layout.din-5008-b) // another page master
#let c = theme.corporate.with(theme.custom.brand(color: rgb("#003a70"))) // a brand is a patch
#let d = theme.elegant(layout: theme.layout.a4-digital) // calling it is the same as .with

#show: invoice.with(theme: b /* , sender: .., recipient: .. */)
```

| Argument    | Type                                 | Description                                                                                                                                                                       |
| :---------- | :----------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `..patches` | `dictionary` \| `array` \| `none`    | Patches, applied in call order on top of the preset's look. `theme.custom` helpers build them. `none` is ignored, so a helper inside a false `if` does nothing.                   |
| `layout`    | `auto` \| `dictionary` \| `function` | The page master. `auto` (default) lets the preset pick one for the sender's country. A function `env => layout` picks one for the environment. The last `.with(layout: ..)` wins. |

Any other named argument panics. A 0.4 parameter such as `form` or `hole-mark` gets a pointer to the [migration guide](./migration.md).

To pick a preset by name, for example from `--input preset=elegant`, look it up in the module:

```typst
#let name = sys.inputs.at("preset", default: "classic")
#show: invoice.with(theme: dictionary(theme).at(name) /* , .. */)
```

## The `theme` Module

| Export                                                                                                                              | Content                                                                                                     | Tier                                         |
| :---------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- | :------------------------------------------- |
| `theme.classic`, `theme.plain`                                                                                                      | presets                                                                                                     | frozen                                       |
| `theme.corporate`, `theme.elegant`, `theme.prestige`, `theme.bold`, `theme.technical`, `theme.soft`, `theme.compact`, `theme.boxed` | presets                                                                                                     | names stable, look experimental              |
| `theme.layout`                                                                                                                      | 16 layouts, `derive`, the envelope catalogue and the region functions ([Layouts](./layouts.md))             | per layout                                   |
| `theme.custom`                                                                                                                      | the patch helpers ([Customization](./customization.md))                                                     | frozen mechanism, provisional option helpers |
| `theme.parts`                                                                                                                       | the built-in renderers ([Parts](./parts.md#built-in-renderers-themeparts))                                  | names frozen                                 |
| `theme.resolve(theme, env:, validation:)`                                                                                           | evaluates a lazy theme outside an invoice ([Testing a theme](./parts.md#testing-a-theme-themeresolve))      | frozen                                       |
| `theme.contrast`, `theme.on-color`, `theme.legible`                                                                                 | color helpers ([Color helpers](./customization.md#color-helpers))                                           | stable                                       |
| `themed(..patches)[body]`                                                                                                           | a scoped override for part of the body; a top-level export ([`themed`](./parts.md#scoped-overrides-themed)) | experimental                                 |

## Stability Tiers

| Tier                            | Promise                                                                            | Contents                                                                                                                                                                                                                                                  |
| :------------------------------ | :--------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Frozen**                      | No breaking change in 0.5.x.                                                       | Calling convention and `layout:`, merge rules, the 30 tokens, the layout and area schema, standard area names, part names and signature, the prefix rule for custom parts, the validation levels, `classic`, `plain`, the stable layouts, `theme.resolve` |
| **Stable names, evolving look** | Name and default layout family stay; the appearance may change in a minor release. | The eight other presets                                                                                                                                                                                                                                   |
| **Provisional**                 | May change in a 0.5.x minor release, with a changelog entry.                       | Options and their helpers, the body views and the frame view fields not marked frozen, issue ids, the envelope catalogue values                                                                                                                           |
| **Experimental**                | May change or be removed.                                                          | `us-letter-10`, `a4-window-right`, `a4-window-left`, `sn-010130-right`, `sn-010130-left`, the sidebar, band and dense layouts, `themed`, `theme.custom.row`, `theme.custom.from-data`, `arrange` functions                                                |
| **0.5.x preview**               | Specified, not final.                                                              | `theme.layout.reserve-qr-bill`, the `qr-bill` part, `fonts.regulated`, the area fields `isolate` and `float`                                                                                                                                              |

## Where to Go Next

- [Customization](./customization.md): `theme.custom`, tokens, options, `brand()`, brand files, checks.
- [Layouts](./layouts.md): built-in layouts, areas, layout by region, envelopes and print proofs, stationery, your own formats.
- [Parts](./parts.md): the part contract, wrapping and replacing parts, views, `themed`, theme packages.
- [Validation](../invoice/validation.md): what a draft marks, when the build stops, and how the ZUGFeRD XML is handled.
- [Migration from 0.4](./migration.md).
