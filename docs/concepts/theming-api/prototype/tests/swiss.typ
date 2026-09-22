// Swiss layouts "simply work": sn-010130-right/-left (and layout: auto for a Swiss
// sender) reserve NO QR-bill zone and print no placeholder slip; the zone is an
// explicit, experimental opt-in: theme.layout.reserve-qr-bill(layout).
//   --input variant=auto|right|left|reserved  --input look=<preset>
#import "/tests/body.typ": *
#let variant = sys.inputs.at("variant", default: "auto")
#let look = sys.inputs.at("look", default: "classic")
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

#let layout = (
  "auto": auto,
  right: L.sn-010130-right,
  left: L.sn-010130-left,
  reserved: L.reserve-qr-bill(L.sn-010130-right),
).at(variant)
#let probe = theme.custom.wrap("qr-bill", (ctx, view, inner) => {
  [#metadata(none) <qr-bill-drawn>]
  inner(ctx, view)
})
#show: invoice.with(
  theme: dictionary(theme).at(look).with(probe, layout: layout),
  locale: locale.de-ch,
  ..party,
  sender: party.sender + (region: "ch"),
)
#body(n: 4)
#context {
  let drawn = query(<qr-bill-drawn>).len()
  let pages = counter(page).final().first()
  if variant == "reserved" {
    assert(drawn == 1, message: "reserve-qr-bill: the zone was not drawn")
  } else {
    assert(
      drawn == 0,
      message: look + "/" + variant + ": a QR-bill placeholder was drawn",
    )
    assert(
      pages == 1,
      message: look + "/" + variant + ": 4 items need " + str(pages) + " pages",
    )
  }
}
