---
sidebar_position: 1
---

# Classic

The default theme: a clean business letter for window envelopes, in the tradition of DIN 5008. It suits every business and is the safe choice when you are unsure. You get it without passing a theme at all.

| Preset             | `theme.classic`, the default of `invoice`                                                                                                                                          |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Best for**       | every business: services, trades, freelancers, B2B and B2C                                                                                                                         |
| **Default layout** | a window layout for the sender's country: `din-5008-a` (DE), `din-5008-b` (AT), `sn-010130-right` (CH), `a4-window-right` (FR, IT, ES), `a4-window-left` (GB), `us-letter-10` (US) |
| **Output**         | print for a window envelope, and PDF                                                                                                                                               |
| **Fonts**          | Liberation Sans (fallback: Libertinus Serif)                                                                                                                                       |
| **Stability**      | frozen: the look does not change in 0.6.x                                                                                                                                          |

![An engineering office's invoice in classic, on DIN 5008 form A](/img/themes/preset-classic.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.classic, // the default: leaving `theme` out gives the same result
  locale: locale.en-de,
  sender: (
    name: "Hartmann Engineering GmbH",
    address: "Leopoldstraße 88",
    city: "80802 Munich",
    vat-id: "DE271234567",
    register: [Local court Munich, HRB 229104],
    management: [Managing director: Sven Hartmann],
    extra: (Phone: "+49 89 2554 1180", Email: "office@hartmann-eng.de"),
  ),
  recipient: (
    name: "Isartal Housing GmbH",
    address: "Wolfratshauser Str. 190",
    city: "81479 Munich",
  ),
  invoice-nr: "2026-117",
)

#line-items[
  #item([Structural design, work stage 3], price: 8400)
  #item([Permit planning, work stage 4], price: 5250)
  #item([Site visits], quantity: 6, unit: unit.hour, price: 145)
]

#payment-terms(days: 30)
#bank-details(
  bank: "Stadtsparkasse München",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Sven Hartmann")
```

## What You Get

- A letterhead with the logo on the left and the sender on the right.
- The recipient in the envelope window, below a one-line return address; the sender's `extra` details (phone, e-mail) beside the window.
- A reference row above the title, and the title with the invoice number, place and date.
- A striped items table in a light tint of the brand color, and the totals under a heavy rule.
- Bank details with the EPC-QR code.
- A legal footer on every page (company, contact, registration, bank account), a continuation header on following pages and "Page 1 of 2".
- Fold and punch marks.

## Make It Yours

Add your brand color and logo, and adjust the page master:

```typst
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(
      color: rgb("#0f766e"), // table stripes and text colors derive from it
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
    theme.custom.marks(punch: none), // fold marks only
    layout: theme.layout.din-5008-b, // the taller letterhead zone of form B
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

## Good to Know

- **PDF only?** `theme.custom.marks(none)` removes the fold and punch marks.
- **Letterhead paper:** `theme.custom.stationery("pre-printed")` drops the letterhead and the footer, so the theme prints only what your paper lacks. See [Stationery](../api-reference/theme/layouts.md#stationery).
- **Another country:** the layout follows `sender.country`. An English invoice from Germany still uses DIN 5008, because the envelope is German. See [Layout by Region](../api-reference/theme/layouts.md#layout-by-region).
- **Starting point for your own parts:** `theme.parts` holds the renderers of `classic`, so a replaced block can start from the classic output. See [Parts](../api-reference/theme/parts.md).
- **Coming from 0.5 or earlier:** `classic` replaces `themes.DIN-5008`. See the [migration guide](../api-reference/theme/migration.md).
