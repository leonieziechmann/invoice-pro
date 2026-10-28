/// [ppi: 12]

// layout: auto picks the page master from the SENDER's region (prototype
// tests/layout-region.typ, scripts/checks-core.sh, checks-presets.sh):
// - real invoices for classic, corporate and plain x de, at, ch, fr, it, es, gb,
//   us, nl (the sender's region comes from the locale for de..es and from the
//   party otherwise); the recipient part reports the layout, paper and region;
// - an explicit `layout:` wins (US sender, din-5008-b);
// - every preset x every region through theme.resolve(env: ..) (the one-page
//   test renders all presets in all regions with layout: auto).
#import "/tests/theme/body.typ": auto-layout, presets
#import "/tests/theme/harness.typ": case, close-cases, in-case
#import "/src/lib.typ": *

#let regions = ("de", "at", "ch", "fr", "it", "es", "gb", "us", "nl")
#let locales = (
  de: locale.de-de,
  at: locale.de-at,
  ch: locale.de-ch,
  fr: locale.fr-fr,
  it: locale.it-it,
  es: locale.es-es,
)
#let probe = theme.custom.wrap("recipient", (ctx, view, inner) => {
  [#metadata((
    layout: ctx.theme.layout.name,
    paper: ctx.theme.layout.paper,
    region: ctx.theme.env.region,
  )) <layout-probe>]
  inner(ctx, view)
})
#let one(key, look, region, explicit: false) = {
  let preset = dictionary(theme).at(look)
  case(
    key,
    theme: if explicit {
      preset.with(probe, layout: theme.layout.din-5008-b)
    } else { preset.with(probe) },
    locale: locales.at(region, default: locale.en-de),
    invoice-nr: "2026-0001",
    sender: (
      name: "Atelier Nord",
      address: "Hafenstrasse 12",
      city: "20457 Hamburg",
      vat-id: "DE123456789",
      ..if region not in locales { (region: region) },
    ),
    recipient: (
      name: "Acme AG",
      address: "Industriestrasse 5",
      city: "70173 Stuttgart",
      region: "de",
    ),
    line-items[#item([Beratung], price: 100)],
  )
}
#let cases = (
  ("classic", "corporate", "plain")
    .map(look => regions.map(r => (look, r)))
    .join()
)
#for (look, r) in cases { one(look + "/" + r, look, r) }
#one("explicit", "classic", "us", explicit: true)
#close-cases()

#context {
  for (look, r) in cases {
    let key = look + "/" + r
    let p = in-case(key, <layout-probe>)
    assert(p.len() >= 1, message: key + ": the recipient part did not render")
    let v = p.first()
    let want = auto-layout(look, r)
    assert(
      v.layout == want,
      message: key + ": expected " + want + ", got " + v.layout,
    )
    let paper = if r == "us" { "us-letter" } else { "a4" }
    assert(
      v.paper == paper,
      message: key + ": expected paper " + paper + ", got " + repr(v.paper),
    )
    assert(v.region == r, message: key + ": env.region " + repr(v.region))
  }
  let x = in-case("explicit", <layout-probe>).first()
  assert(
    x.layout == "din-5008-b" and x.paper == "a4",
    message: "an explicit layout must win: " + repr(x),
  )
}

// every preset x every region: the mapping through the resolver
#let env(r) = (kind: "invoice", lang: "de", region: r, e-invoice: none)
#for look in presets {
  for r in regions {
    let got = theme.resolve(dictionary(theme).at(look), env: env(r))
    assert.eq(got.layout.name, auto-layout(look, r), message: look + "/" + r)
    assert.eq(
      got.layout.paper,
      if r == "us" { "us-letter" } else { "a4" },
      message: look + "/" + r,
    )
  }
}

// pure API: the mapping, the fallback and resolvers on resolve
#assert(theme.layout.for-region("CH").name == "sn-010130-right")
#assert(
  theme.layout.for-region("nl").name == "din-5008-a"
    and theme.layout.for-region(none).name == "din-5008-a",
)
#assert(
  theme.layout.for-region("xx", default: theme.layout.a4-digital).name
    == "a4-digital",
)
#assert(
  theme.layout.paper-for-region("us") == "us-letter"
    and theme.layout.paper-for-region("de") == "a4",
)
#assert(
  theme.resolve(theme.classic, env: env("at")).layout.name == "din-5008-b",
)
#assert(
  theme.resolve(theme.corporate, env: env("us")).layout.paper == "us-letter",
)
#assert(theme.resolve(theme.plain, env: env("us")).layout.paper == "us-letter")
#assert(
  theme
    .resolve(
      theme.classic.with(layout: theme.layout.a4-digital),
      env: env("us"),
    )
    .layout
    .name
    == "a4-digital",
)
// a user resolver works like a preset's
#assert(
  theme
    .resolve(
      theme.classic.with(layout: e => theme.layout.digital-for-region(
        e.region,
      )),
      env: env("us"),
    )
    .layout
    .name
    == "us-letter-digital",
)
