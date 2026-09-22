// Helper/schema coverage (the I-6 lesson): every schema key has a helper parameter.
#import "/src/lib.typ": *
#import "/src/theming/schema.typ": option-schema, token-schema
#let probe(helper, group, keys) = {
  let out = helper(..keys.map(k => (k, 1)).to-dict())
    .first()
    .values()
    .first()
    .at(group)
  assert(
    out.keys().sorted() == keys.sorted(),
    message: "helper for " + group + " drifted",
  )
}
#for (g, s) in token-schema {
  probe(dictionary(theme.custom).at(g), g, s.keys())
}
#for (g, s) in option-schema {
  if g != "custom" { probe(dictionary(theme.custom).at(g), g, s.keys()) }
}
// checks helper == check schema (checks emits the group directly)
#import "/src/theming/schema.typ": check-schema
#assert(
  theme
    .custom
    .checks(
      ..check-schema
        .keys()
        .map(k => (k, if k == "pairs" { (:) } else { 1 }))
        .to-dict(),
    )
    .first()
    .checks
    .keys()
    .sorted()
    == check-schema.keys().sorted(),
  message: "checks helper drifted",
)
// ... and the other way round: every token/option helper is named after a schema group
// (helper name == group name); the rest are layout, part, check and macro helpers.
#let non-group = (
  "page",
  "stationery",
  "marks",
  "envelopes",
  "proof",
  "area",
  "part",
  "wrap",
  "checks",
  "brand",
  "from-data",
  "replace",
  "reset",
)
#for (k, v) in dictionary(theme.custom) {
  if type(v) == function and k not in non-group {
    assert(
      k in token-schema or k in option-schema,
      message: "helper " + k + " has no schema group of that name",
    )
  }
}
// block DSL: several helpers of the SAME group in one block all apply (locale bug I-1 fixed)
#let t = theme.resolve(theme.classic.with({
  import theme.custom: *
  colors(primary: rgb("#0f766e"))
  colors(text-muted: rgb("#555555"))
  page(margin: (bottom: 40mm))
}))
#assert(
  t.tokens.colors.primary == rgb("#0f766e")
    and t.tokens.colors.text-muted == rgb("#555555"),
)
#assert(t.layout.margin == (top: 20mm, right: 20mm, bottom: 40mm, left: 25mm)) // sides fold
#assert(t.tokens.colors.on-primary == white) // derived
#assert(t.tokens.colors.tint != rgb("#e2e8f0")) // re-derived from seed
#let d = theme.resolve(theme.classic)
#assert(d.tokens.colors.tint.to-hex() == "#e2e8f0") // default seed reproduces historic zebra
#assert(d.layout.marks.stroke == 0.25pt + black) // marks derive from strokes.hairline + colors.text
// chain later-wins, called == uncalled
#let a = theme.resolve(
  theme
    .classic
    .with(theme.custom.colors(primary: red))
    .with(theme.custom.colors(primary: blue)),
)
#let b = theme.resolve(
  theme.classic(theme.custom.colors(primary: red))(
    theme.custom.colors(primary: blue),
  ),
)
#assert(a.tokens.colors.primary == blue and b.tokens == a.tokens)
// layout swap keeps look patches (corporate's letterhead rule on DIN B)
#let m = theme.resolve(theme.corporate.with(layout: theme.layout.din-5008-b))
#assert(
  m.layout.areas.letterhead.rule.stroke
    == m.tokens.strokes.regular + m.tokens.colors.accent
    and m.layout.areas.address.top == 45mm,
)
// look lint: looks patch only look-safe area fields (never geometry)
#import "/src/theming/presets.typ": looks
#import "/src/theming/schema.typ": area-style-fields
#import "/tests/looks.typ": minimal-look
#for (name, look) in looks + (minimal: minimal-look) {
  for p in look.flatten() {
    for (rn, rv) in p.at("layout", default: (:)).at("areas", default: (:)) {
      for k in rv.keys() {
        assert(
          k in area-style-fields,
          message: "look " + name + " patches geometry field " + rn + "::" + k,
        )
      }
    }
  }
}
ALL COVERAGE ASSERTIONS PASSED
