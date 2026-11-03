// (f) custom fields: document custom via info.get and dynamic (sealed in
// ctx, unsealed for reads), party custom via ctx.recipient.custom, item
// custom via the line view of a theme wrap. `--input lib=pristine` shows
// that 0.6.0 warns about the party key (IP-KEY-01).
#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *
#let repo = sys.inputs.at("lib", default: "repo") == "repo"
#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "ACME GmbH",
    address: "Weg 1",
    city: "80331 München",
    country: "DE",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Kunde AG",
    address: "Gasse 2",
    city: "10115 Berlin",
    country: "DE",
    custom: (segment: "enterprise"),
  ),
  invoice-nr: "C-1",
  date: datetime(year: 2026, month: 11, day: 2),
  ..if repo { (custom: (tarif: "Gold")) },
)
Tarif: #info.get("custom", "tarif", default: "none") \
Segment: #dynamic(ctx => ctx.recipient.at("custom", default: (:)).at(
  "segment",
  default: "none",
)) \
Dyn-Tarif: #dynamic(ctx => {
  let c = ctx.at("custom", default: none)
  if type(c) == dictionary { c.tarif } else { repr(type(c)) }
})
#line-items[#item("A", price: "10.00", tax: 19%)]
#payment-terms(days: 14)
