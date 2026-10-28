/// [ppi: 12]

// Swiss layouts "simply work" (prototype tests/swiss.typ, checks-fix-layouts.sh):
// sn-010130-right/-left (and layout: auto for a Swiss sender) reserve NO QR-bill
// zone and print no placeholder slip, and 4 items fit on one page, for every
// preset; the zone is the explicit, experimental opt-in
// theme.layout.reserve-qr-bill(layout).
#import "/tests/theme/body.typ": *
#import "/tests/theme/harness.typ": case, close-cases, in-case, span-of

#let L = theme.layout

// pure API
#assert(L.for-region("ch").name == "sn-010130-right")
#assert("qr-bill" not in L.sn-010130-right.areas)
#assert("qr-bill" not in L.sn-010130-left.areas)
#let res = L.reserve-qr-bill(L.sn-010130-right)
#assert(res.name == "sn-010130-right" and "qr-bill" in res.areas)
#assert(res.areas.qr-bill.height == 105mm and res.areas.qr-bill.isolate)
// the helper leaves its argument alone and composes with the left variant
#assert("qr-bill" not in L.sn-010130-right.areas)
#assert("qr-bill" in L.reserve-qr-bill(L.sn-010130-left).areas)
// layout: auto for a Swiss sender resolves to sn-010130-right without the zone
#let ch-env = (kind: "invoice", lang: "de", region: "ch", e-invoice: none)
#let ch = theme.resolve(theme.classic, env: ch-env).layout
#assert(ch.name == "sn-010130-right")
#assert(ch.areas.at("qr-bill", default: none) == none)

#let variants = (
  "auto": auto,
  right: L.sn-010130-right,
  left: L.sn-010130-left,
  reserved: L.reserve-qr-bill(L.sn-010130-right),
)
#let probe = theme.custom.wrap("qr-bill", (ctx, view, inner) => {
  [#metadata(none) <qr-bill-drawn>]
  inner(ctx, view)
})
#let cases = (
  presets.map(p => (p + "/right", p + "/left")).join()
    + ("classic/auto", "classic/reserved")
)
#for key in cases {
  let (look, variant) = key.split("/")
  case(
    key,
    theme: preset-of(look).with(probe, layout: variants.at(variant)),
    locale: locale.de-ch,
    ..party,
    sender: party.sender + (region: "ch"),
    body(n: 4),
  )
}
#close-cases()

#context for key in cases {
  let drawn = in-case(key, <qr-bill-drawn>).len()
  if key.ends-with("/reserved") {
    assert(drawn == 1, message: "reserve-qr-bill: the zone was not drawn")
  } else {
    let pages = span-of(key).pages
    assert(drawn == 0, message: key + ": a QR-bill placeholder was drawn")
    assert(
      pages == 1,
      message: key + ": 4 items need " + str(pages) + " pages",
    )
  }
}
