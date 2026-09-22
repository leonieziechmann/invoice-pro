// layout: auto picks the page master from the SENDER's region (env.region).
//   --input region=de|at|ch|fr|it|es|gb|us|nl|base  --input look=<any preset>
//   --input explicit=1  (an explicit `layout:` must win over the region)
// Real invoices: the sender's `region` (or the locale) decides; the recipient part
// reports the layout it was rendered on, and the test asserts it.
#import "/src/lib.typ": *

#let region = sys.inputs.at("region", default: "de")
#let look = sys.inputs.at("look", default: "classic")
#let explicit = sys.inputs.at("explicit", default: "0") == "1"

// expected layout per look and region (the maintainer's mapping)
#let window = (
  de: "din-5008-a",
  at: "din-5008-b",
  ch: "sn-010130-right",
  fr: "a4-window-right",
  it: "a4-window-right",
  es: "a4-window-right",
  gb: "a4-window-left",
  us: "us-letter-10",
)
#let us = region == "us"
#let win = window.at(region, default: "din-5008-a")
#let expected = if explicit { "din-5008-b" } else {
  (
    classic: win,
    boxed: win,
    // the centred serif letterhead needs form B's zone: form A becomes form B
    elegant: if win == "din-5008-a" { "din-5008-b" } else { win },
    corporate: if us { "us-letter-sidebar" } else { "a4-sidebar" },
    prestige: if us { "us-letter-band" } else { "a4-band" },
    bold: if us { "us-letter-digital" } else { "a4-digital" },
    technical: if us { "us-letter-digital" } else { "a4-digital" },
    soft: if us { "us-letter-digital" } else { "a4-digital" },
    compact: if us { "us-letter-dense" } else { "a4-dense" },
    plain: "plain",
  ).at(look)
}
#let expected-paper = if explicit { "a4" } else if region == "us" {
  "us-letter"
} else { "a4" }

// locales exist for at/ch/de/es/fr/it; other senders set their region on the party
#let loc = (
  de: locale.de-de,
  at: locale.de-at,
  ch: locale.de-ch,
  fr: locale.fr-fr,
  it: locale.it-it,
  es: locale.es-es,
).at(region, default: locale.en-de)
#let sender-region = if region in ("de", "at", "ch", "fr", "it", "es") {
  (:)
} else { (region: region) }

#let preset = dictionary(theme).at(look)
#let probe = theme.custom.wrap("recipient", (ctx, view, inner) => {
  [#metadata((
    layout: ctx.theme.layout.name,
    paper: ctx.theme.layout.paper,
    region: ctx.theme.env.region,
  )) <layout-probe>]
  inner(ctx, view)
})
#let th = if explicit {
  preset.with(probe, layout: theme.layout.din-5008-b)
} else { preset.with(probe) }

#show: invoice.with(
  theme: th,
  locale: loc,
  invoice-nr: "2026-0001",
  sender: (
    name: "Atelier Nord",
    address: "Hafenstrasse 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
    ..sender-region,
  ),
  recipient: (
    name: "Acme AG",
    address: "Industriestrasse 5",
    city: "70173 Stuttgart",
    region: "de",
  ),
)
#line-items[#item([Beratung], price: 100)]

#context {
  let p = query(<layout-probe>)
  assert(p.len() >= 1, message: "the recipient part did not render")
  let v = p.first().value
  assert(
    v.layout == expected,
    message: "region "
      + region
      + " / "
      + look
      + ": expected "
      + expected
      + ", got "
      + v.layout,
  )
  assert(
    v.paper == expected-paper,
    message: "region "
      + region
      + ": expected paper "
      + expected-paper
      + ", got "
      + repr(v.paper),
  )
  let r = if region == "base" { "base" } else { region }
  if region in window or region == "nl" {
    assert(v.region == r, message: "env.region " + repr(v.region))
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
#let env(r) = (kind: "invoice", lang: "de", region: r, e-invoice: none)
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
