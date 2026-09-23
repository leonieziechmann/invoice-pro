/// [ppi: 12]

// Walkthroughs and concept snippets, compile-only (prototype tests/walk.typ,
// tests/third-party.typ and tests/doc/*.typ, generated from the typst blocks of
// docs/concepts/theming-api/README.md):
// - personas P1, P4, P6, P8 and the scoped styles of P10 on the shared body;
// - a zero-import third-party theme package (tests/theme/acme-theme.typ);
// - every snippet of the concept (walkthroughs P1..P10, parts, passing a theme,
//   presets, proof, receipt, region, a derived layout), each as one invoice of
//   this document, with its sys.inputs variants spelled out (the validation
//   snippet: tests/validation/concept-draft, a draft report needs its own
//   document);
// - the §3.3 listing of din-5008-a/b equals the shipped layouts.
// The stationery modes of P2 render in tests/theme/stationery-*.
#import "/tests/theme/body.typ": body, logo-img, party
#import "/tests/theme/doc-prelude.typ": doc-body, doc-party
#import "/tests/theme/acme-theme.typ" as acme
#import "/tests/theme/harness.typ": case, close-cases, spans
#import "/tests/test-locale.typ": test-locale
#import "/src/lib.typ": *

#let A = "/tests/theme/assets/"
#let n = state("walkthrough-cases", 0)
#let walk(key, ..args, content) = {
  n.update(x => x + 1)
  case(key, ..args, content)
}

// --- personas on the shared body (prototype tests/walk.typ) ----------------------
// P1 freelancer, five minutes
#walk(
  "walk/p1",
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#0f766e"), logo: logo-img),
    theme.custom.marks(none),
  ),
  locale: test-locale,
  ..party,
  body(n: 5),
)
// P4 agency: brand from TOML, logo path resolved by the user's loader
#let entity = toml(A + "nordlicht.toml")
#walk(
  "walk/p4",
  theme: theme.corporate.with(theme.custom.from-data(
    entity.theme,
    assets: p => image(A + p, alt: entity.sender.name),
  )),
  locale: test-locale,
  ..party,
  body(n: 5),
)
// P6 design studio: band look on DIN B, wrap + replace + re-parameterised inner
#walk(
  "walk/p6",
  theme: theme.corporate(layout: theme.layout.din-5008-b, {
    // called form == .with
    import theme.custom: *
    brand(color: rgb("#111827"), accent: rgb("#6366f1"), logo: logo-img)
    totals(width: 100%, fill: none)
    wrap("totals", (ctx, view, inner) => block(
      stroke: (left: 3pt + ctx.theme.tokens.colors.accent),
      inset: (left: 6pt),
      inner(ctx, view),
    ))
    part("payment-terms", (ctx, view) => block(
      fill: ctx.theme.tokens.colors.accent.lighten(88%),
      inset: 1em,
      radius: 4pt,
      text(
        size: 1.2em,
      )[Fällig in #view.days Tagen: *#(ctx.locale.format.currency)(view.total)*],
    ))
    area("letterhead", parts: ("sender", "logo")) // logo right: data, no renderer
  }),
  locale: test-locale,
  ..party,
  body(n: 5),
)
// P8 US subsidiary: same brand, US Letter #10, remit-to footer as content blocks
#walk(
  "walk/p8",
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#003a70"), logo: logo-img),
    layout: theme.layout.us-letter-10,
    theme.custom.area(
      "footer",
      parts: (
        [*Remit to:* ACME Inc., PO Box 12, Austin TX],
        [billing\@acme.com],
        "registration",
      ),
      arrange: (columns: (1fr, 1fr, 1fr)),
    ),
  ),
  locale: test-locale,
  ..party,
  body(n: 5),
)
// P10 scoped styles
#walk("walk/scope", theme: theme.plain, locale: test-locale, ..party, [
  Scoped styles (persona 10):
  #line-items[
    #group([Phase 1])[#item([Konzeption], price: 1800)]
    #themed(theme.custom.row(fill: rgb("#fef3c7")))[
      #group([Phase 2 - optional])[#item([Reinzeichnung], price: 650) #item(
          [Druck],
          price: 240,
        )]
    ]
  ]
  #themed({
    import theme.custom: *
    colors(primary: rgb("#b91c1c"))
    wrap("bank-details", (ctx, view, inner) => block(
      fill: ctx.theme.tokens.colors.tint,
      inset: 8pt,
      inner(ctx, view),
    ))
  })[#bank-details(
    bank: "Hamburger Sparkasse",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )]
  #signature()
])
// a third-party theme package: pure data, no invoice-pro import
#walk(
  "third-party",
  theme: theme.classic.with(acme.patch, layout: acme.sidebar-a5),
  locale: test-locale,
  ..party,
  body(n: 4),
)

// --- the concept's snippets (prototype tests/doc/*.typ) ----------------------------
// P1
#walk(
  "doc/p1",
  theme: theme.classic.with(
    theme.custom.brand(
      color: rgb("#0f766e"),
      font: ("Inter", "Liberation Sans", "Libertinus Serif"),
      logo: image(A + "logo.svg", alt: "Studio Lina Berg"),
    ),
    theme.custom.marks(none),
  ),
  locale: locale.de-de,
  tax-exempt-small-biz: true,
  ..doc-party,
  doc-body(),
)
// P2, --input output=print|pdf|einvoice
#let acme-brand = theme.custom.brand(
  color: rgb("#003a70"),
  accent: rgb("#e2001a"),
  font: ("Source Sans 3", "Liberation Sans", "Libertinus Serif"),
  logo: image(A + "acme.svg", alt: "ACME Maschinenbau GmbH"),
)
#for mode in ("print", "pdf", "einvoice") {
  walk(
    "doc/p2/" + mode,
    theme: theme.classic.with(acme-brand, layout: theme.layout.din-5008-b, {
      import theme.custom: *
      if mode == "print" { stationery("pre-printed") }
      if mode == "pdf" {
        stationery((first: image(A + "lh1.svg"), rest: image(A + "lh2.svg")))
        area("continuation", none) // the rest-page art carries its own header
      }
      if mode != "print" { marks(none) }
    }),
    locale: locale.de-de,
    ..doc-party,
    zugferd: if mode == "einvoice" { "basic" },
    doc-body(n: 4),
  )
}
// P3, --input qr-bill=1 and --input window=left
#let sn = theme.layout.sn-010130-right // what layout: auto picks for a Swiss sender
#for qr-bill in (false, true) {
  for window in ("right", "left") {
    walk(
      "doc/p3/" + window + (if qr-bill { "/qr-bill" } else { "" }),
      locale: locale.de-ch,
      ..doc-party,
      theme: theme.classic.with(
        layout: if qr-bill { theme.layout.reserve-qr-bill(sn) } else { sn },
        {
          import theme.custom: *
          brand(
            color: rgb("#7a1f2b"),
            font: ("Source Serif 4", "Libertinus Serif"),
          )
          if window == "left" {
            area("address", left: 22mm) // setting left clears right
            area("info", right: 18mm) // setting right clears left
          }
        },
      ),
      doc-body(n: 4),
    )
  }
}
// P4
#let e = toml(A + "nordlicht.toml")
#walk(
  "doc/p4",
  theme: theme.corporate.with(theme.custom.from-data(
    e.theme,
    assets: p => image(A + p, alt: e.sender.name),
  )),
  locale: locale.de-de,
  ..doc-party,
  sender: doc-party.sender + e.sender,
  doc-body(),
)
// P5: theme.typ of the pipeline, built once, an immutable value
#let company = theme.classic.with(
  theme.custom.from-data(json(A + "brand.json")),
  theme.custom.checks(min-contrast: 4.5),
)
#let locales = (de-de: locale.de-de, en-de: locale.en-de) // explicit map, no reflection
#let job = json(A + "job.json")
#walk(
  "doc/p5",
  theme: company.with(layout: theme.layout.digital-for-region(job.region)),
  locale: locales.at(job.locale),
  ..doc-party,
  doc-body(),
)
// P6
#walk("doc/p6", locale: locale.de-de, ..doc-party, theme: theme.corporate(
  layout: theme.layout.din-5008-b,
  {
    import theme.custom: *
    brand(
      color: rgb("#111827"),
      accent: rgb("#6366f1"),
      font: ("Inter", "Libertinus Serif"),
      heading-font: ("Fraunces", "Libertinus Serif"),
      logo: image(A + "logo.svg", alt: "Atelier Nord"),
    )
    area("letterhead", parts: ("sender", "logo")) // logo right: data, no renderer
    totals(width: 100%, fill: none)
    wrap("totals", (ctx, view, inner) => block(
      stroke: (left: 3pt + ctx.theme.tokens.colors.accent),
      inset: (left: 6pt),
      inner(ctx, view),
    ))
    part("payment-terms", (ctx, view) => {
      let amount = (ctx.locale.format.currency)(view.total)
      let fill = ctx.theme.tokens.colors.accent.lighten(88%)
      let due = [Fällig in #view.days Tagen: *#amount*]
      block(fill: fill, inset: 1em, text(size: 1.2em, due))
    })
  },
))[#doc-body()]
// P7
#walk("doc/p7", locale: locale.de-de, ..doc-party, theme: theme.classic.with(
  theme.custom.brand(
    color: rgb("#00843d"),
    logo: image(A + "sw.svg", alt: "Stadtwerke Musterstadt"),
  ),
  theme.custom.checks(min-contrast: 4.5),
  theme.custom.marks(none),
))[#doc-body()]
// P8: the same brand patch as in P2
#let corporate = theme.custom.brand(
  color: rgb("#003a70"),
  accent: rgb("#e2001a"),
)
#walk("doc/p8", locale: locale.en-de, ..doc-party, theme: theme.classic.with(
  corporate,
  layout: theme.layout.us-letter-10,
  theme.custom.area("footer", arrange: (columns: (1fr, 1fr, 1fr)), parts: (
    [*Remit to:* #info.sender.name, PO Box 12, Austin TX],
    [billing\@acme.com],
    "registration",
  )),
))[#doc-body()]
// P9: a zero-import package, and its CI against invoice-pro
#walk("doc/p9", locale: locale.de-de, ..doc-party, theme: theme.classic.with(
  acme.patch,
  layout: acme.sidebar-a5,
))[#doc-body()]
#let _ = theme.resolve(theme.classic.with(acme.patch, layout: acme.sidebar-a5))
// P10
#walk("doc/p10", locale: locale.de-de, ..doc-party)[
  #line-items[
    #group([Phase 1])[#item([Konzeption], price: 1800)]
    #themed(theme.custom.row(fill: rgb("#fef3c7")))[
      #group([Phase 2 (optional)])[
        #item([Reinzeichnung], price: 650)
        #item([Druck], price: 240)
      ]
    ]
  ]
  #themed({
    import theme.custom: *
    colors(primary: rgb("#b91c1c")) // tint re-derives inside the scope
    wrap("bank-details", (ctx, view, inner) => block(
      fill: ctx.theme.tokens.colors.tint,
      inset: 8pt,
      inner(ctx, view),
    ))
  })[#bank-details(bank: "Hamburger Sparkasse", iban: "DE75512108001245126199")]
]
// parts: replace, wrap, eject
#walk(
  "doc/parts",
  locale: locale.de-de,
  ..doc-party,
  theme: theme.classic.with({
    import theme.custom: *
    part("signature", (ctx, view) => [— #view.name]) // replace
    wrap("bank-details", (ctx, view, inner) => block(
      fill: ctx.theme.tokens.colors.tint,
      inset: 8pt,
      inner(ctx, view),
    )) // wrap
    part("totals", (ctx, view) => {
      // eject: start from the default renderer, then edit
      set text(fill: ctx.theme.tokens.colors.primary)
      theme.parts.totals(ctx, view)
    })
  }),
)[#doc-body()]
// passing a theme
#let passing = (
  a: theme.classic, // the default
  b: theme.classic.with(layout: theme.layout.us-letter-digital), // another page master
  c: theme.corporate.with(theme.custom.brand(color: rgb("#003a70"))), // a brand is a patch array
  d: theme.classic.with(acme.patch, layout: acme.sidebar-a5), // a zero-import package
)
#walk("doc/passing", theme: passing.d, locale: locale.de-de, ..doc-party)[
  #doc-body()
]
#for th in (passing.a, passing.b, passing.c) { let _ = theme.resolve(th) }
// presets, --input preset=<any of the ten>
#let brand = theme.custom.brand(
  color: rgb("#0f766e"),
  logo: image(A + "logo.svg", alt: "Atelier Nord"),
)
#for pick in (
  "classic",
  "plain",
  "corporate",
  "elegant",
  "prestige",
  "bold",
  "technical",
  "soft",
  "compact",
  "boxed",
) {
  walk(
    "doc/presets/" + pick,
    locale: locale.de-de,
    ..doc-party,
    theme: dictionary(theme).at(pick).with(brand),
    doc-body(),
  )
}
// proof, --input proof=1
#for proof-on in (false, true) {
  walk(
    "doc/proof/" + repr(proof-on),
    locale: locale.de-de,
    ..doc-party,
    theme: theme.classic.with({
      import theme.custom: *
      envelopes(theme.layout.envelope.din-dl, (
        name: "ours-c6-5",
        size: (229mm, 114mm),
        fold: (87mm, 192mm),
        window: (left: 22mm, bottom: 16mm, width: 90mm, height: 45mm),
      ))
      proof(proof-on)
    }),
    doc-body(),
  )
}
// any format is data: an 80 mm thermal-roll receipt (continuous page)
#let roll = (
  name: "roll-80",
  paper: (width: 80mm, height: auto),
  marks: none,
  margin: (x: 4mm, top: 6mm, bottom: 16mm),
  areas: (
    letterhead: (place: "before", parts: ("sender",), align: center),
    title: (place: "before", parts: ("title",)),
    address: (place: "before", parts: ("recipient",)),
    footer: (place: "footer", parts: ("registration",), text: (size: 6pt)),
  ),
)
#walk("doc/receipt", locale: locale.de-de, ..doc-party, theme: theme.plain.with(
  layout: roll,
  theme.custom.sizes(body: 8pt, fine: 6pt),
  theme.custom.title(show-place-date: true),
))[#doc-body(n: 3)]
// layout: auto follows the SENDER's country: AT -> din-5008-b
#let vienna = (address: "Kärntner Ring 5", city: "1010 Wien", country: "AT")
#walk(
  "doc/region",
  locale: locale.de-at,
  ..doc-party,
  sender: doc-party.sender + vienna,
  theme: theme.classic, // pin one: theme.classic.with(layout: ..)
  doc-body(),
)
// a company-specific window: geometry lives in a derived layout, not in patches
#let our-window = theme.layout.derive(theme.layout.din-5008-a, {
  import theme.custom: *
  area("address", left: 24mm, top: 40mm)
  area("info", top: 45mm)
  page(margin: (bottom: 35mm))
})
#walk(
  "doc/layout",
  locale: locale.de-de,
  ..doc-party,
  theme: theme.classic.with(layout: our-window),
  doc-body(),
)
#close-cases()
#context assert.eq(spans().len(), n.final())

// --- §3.3: the listing of din-5008-a and din-5008-b equals the shipped data --------
#let derive = theme.layout.derive
#let E = theme.layout
#let din-5008-a = (
  name: "din-5008-a",
  paper: "a4",
  margin: (top: 20mm, right: 20mm, bottom: auto, left: 25mm), // bottom: footer + descent + clearance
  marks: (fold: (87mm, 192mm), punch: 148.5mm, left: 5mm, length: 2.5mm), // stroke: hairline + text
  envelopes: E.folded(
    (87mm, 192mm),
    E.envelope.din-dl,
    E.envelope.din-c6-5,
    E.envelope.din-c5-a,
    E.envelope.din-c4-a,
  ),
  areas: (
    marks: (place: "background", parts: ("marks",)),
    letterhead: (
      left: 25mm,
      top: 8mm,
      width: 165mm,
      height: 19mm,
      stationery: true,
      par: (leading: 0.5em),
      parts: ("logo", "sender"),
      arrange: (columns: (1fr, auto), align: (left + horizon, right + top)),
    ),
    address: (
      left: 20mm,
      top: 27mm,
      width: 85mm,
      height: 45mm,
      inset: (left: 5mm, right: 5mm),
      par: (leading: 0.5em),
      parts: ("return-address", "recipient"),
      gap: 0pt,
      arrange: (rows: (17.7mm, 27.3mm), align: (left + bottom, left + top)),
    ),
    info: (
      left: 125mm,
      top: 32mm,
      width: 75mm,
      height: 40mm,
      parts: ("sender-details",),
    ),
    references: (place: "before", parts: ("references",)),
    title: (place: "before", parts: ("title",)),
    continuation: (place: "header", pages: "rest", parts: ("continuation",)),
    page-number: (place: "footer", parts: ("page-number",), align: right),
    footer: (
      place: "footer",
      stationery: true,
      text: (size: t => t.sizes.fine, fill: t => t.colors.text-muted),
      par: (leading: 0.45em),
      parts: ("company", "contact", "registration", "bank-account"),
      arrange: (columns: (1fr, 1fr, 1fr, 1fr)),
    ),
  ),
)
#let din-5008-b = derive(din-5008-a, (
  layout: (
    name: "din-5008-b",
    marks: (fold: (105mm, 210mm)),
    envelopes: E.folded(
      (105mm, 210mm),
      E.envelope.din-dl,
      E.envelope.din-c6-5,
      E.envelope.din-c5-b,
    ),
    areas: (
      letterhead: (height: 37mm),
      address: (top: 45mm),
      info: (top: 50mm),
    ),
  ),
))
#let R(l) = theme.resolve(theme.classic.with(layout: l)).layout
#assert(R(din-5008-a) == R(theme.layout.din-5008-a))
#assert(R(din-5008-b) == R(theme.layout.din-5008-b))

// the doc logos are logo-sized marks, not the full-page letterhead fixture
#for f in ("acme.svg", "logo.svg", "sw.svg") {
  assert(not read(A + f).contains("height=\"297mm\""), message: f)
}
