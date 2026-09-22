// Persona walkthroughs on ONE body (--input p=p1|p4|p6|p8|scope).
#import "/tests/body.typ": *
#let p = sys.inputs.at("p", default: "p1")

// P1 freelancer, five minutes
#let p1 = theme.classic.with(
  theme.custom.brand(color: rgb("#0f766e"), logo: logo-img),
  theme.custom.marks(none),
)
// P4 agency: brand from TOML, logo path resolved by the user's loader
#let entity = toml("/tests/nordlicht.toml")
#let p4 = theme.corporate.with(theme.custom.from-data(
  entity.theme,
  assets: p => image("/tests/" + p, alt: entity.sender.name),
))
// P6 design studio: band look on DIN B, wrap + replace + re-parameterised inner
#let p6 = theme.corporate(layout: theme.layout.din-5008-b, {
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
})
// P8 US subsidiary: same brand, US Letter #10, remit-to footer as content blocks
#let corporate = theme.custom.brand(color: rgb("#003a70"), logo: logo-img)
#let p8 = theme.classic.with(
  corporate,
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
)

#show: invoice.with(
  theme: (p1: p1, p4: p4, p6: p6, p8: p8, scope: theme.plain).at(p),
  locale: test-locale,
  ..party,
)
#if p != "scope" { body(n: 5) } else [
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
]
