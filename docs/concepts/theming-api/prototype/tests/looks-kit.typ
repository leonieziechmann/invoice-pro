// presets-display: layout by region for bold / compact, the looks kit helpers,
// and the look lint on the new looks (tests/coverage.typ lints every look in
// presets.looks). Compiles to an empty page when every assertion holds.
#import "/src/lib.typ": *
#import "/src/theming/looks/kit.typ": fit-size, payable-label, split-seller-ids
#import "/src/theming/looks/bold.typ": disc-color
#import "/src/theming/color.typ": contrast

#let env(region) = (
  kind: "invoice",
  lang: "de",
  region: region,
  e-invoice: none,
)
// layout: auto follows the sender's region; digital-first bold picks the digital paper
#for (r, b, c) in (
  ("de", "a4-digital", "a4-dense"),
  ("ch", "a4-digital", "a4-dense"),
  ("us", "us-letter-digital", "us-letter-dense"),
  (none, "a4-digital", "a4-dense"),
) {
  assert.eq(theme.resolve(theme.bold, env: env(r)).layout.name, b)
  assert.eq(theme.resolve(theme.compact, env: env(r)).layout.name, c)
}
// an explicit layout always wins
#assert.eq(
  theme
    .resolve(theme.bold.with(layout: theme.layout.din-5008-b), env: env("us"))
    .layout
    .name,
  "din-5008-b",
)
#assert.eq(
  theme
    .resolve(
      theme.compact.with(layout: theme.layout.a4-window-right),
      env: env("de"),
    )
    .layout
    .name,
  "a4-window-right",
)
// the dense layout computes its bottom margin
#assert.eq(theme.layout.a4-dense.margin.bottom, auto)
#assert.eq(theme.layout.us-letter-dense.paper, "us-letter")

// payable-label: amount due after prepayments, else the total (frame view)
#let strings = (summary: (total: "Total", amount-due: "Amount due"))
#let ctx = (locale: (strings: strings))
#assert.eq(payable-label(ctx, (totals: (prepaid: (value: 0)))), "Total")
#assert.eq(
  payable-label(ctx, (totals: (prepaid: (value: decimal("12.5"))))),
  "Amount due",
)

// split-seller-ids: the seller's VAT ID and tax number leave the reference list
#let view = (
  sender: (vat-id: "DE123456789", tax-nr: "22 123 45678"),
  references: (
    ("Kundennummer", "K-1"),
    ("USt-IdNr.", "DE 123 456 789"),
    ("Steuernummer", "22 123 45678"),
    ("Empfänger:in USt-IdNr.", "ATU1234"),
  ),
)
#let s = split-seller-ids(view)
#assert.eq(s.refs.map(r => r.at(0)), ("Kundennummer", "Empfänger:in USt-IdNr."))
#assert.eq(s.seller.map(r => r.at(0)), ("USt-IdNr.", "Steuernummer"))

// fit-size: the largest size that fits, else the last
#context {
  let w(size) = text(size: size, "Abschlagsrechnung")
  let steps = (40pt, 30pt, 20pt, 10pt)
  assert.eq(fit-size(w, 1000pt, steps), 40pt)
  assert.eq(fit-size(w, measure(w(20pt)).width + 1pt, steps), 20pt)
  assert.eq(fit-size(w, 1pt, steps), 10pt)
}

// the bold disc stays legible under on-primary for dark, very dark and light seeds
#for p in (
  rgb("#2b2bd9"),
  rgb("#111111"),
  rgb("#000000"),
  rgb("#0f766e"),
  rgb("#ffd400"),
) {
  let t = theme
    .resolve(theme.bold.with(theme.custom.brand(color: p)), env: env("de"))
    .tokens
  let d = disc-color(t)
  assert(d != p, message: "disc must differ from the block")
  assert(
    contrast(t.colors.on-primary, d) >= 4.5,
    message: "disc contrast for " + p.to-hex(),
  )
}
