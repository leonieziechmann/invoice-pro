// Gallery: `bold` for a Berlin brand and motion studio (English invoice from
// Germany: project fees, licences, a package discount, optionally a deposit).
// Default layout: layout auto (sender region de -> a4-digital).
//   typst compile --root . tests/gallery/bold.typ out/gallery/bold-{p}.png --ppi 110
//   --input layout=<name>   render on another layout
//   --input n=<k>           only the first k items
//   --input deposit=1       a deposit was paid (the block and the bar say "Amount due")
//   --input logo=0          without the logo image
//   --input zugferd=1       attach ZUGFeRD (compile with --pdf-standard a-3b)
//   --input check=1         checks(min-contrast: 4.5)
//   --input title=<word>    another document word (locale.custom), e.g. a long one
//   --input seed=<hex>      another brand colour, e.g. 111111 or ffd400
//   --input lang=de|fr      German or French strings (region de)
//   --input fonts=embedded  no brand logo check: compile with --ignore-system-fonts
#import "/src/lib.typ": *

#let lay = sys.inputs.at("layout", default: none)
#let n = int(sys.inputs.at("n", default: "8"))
#let with-logo = sys.inputs.at("logo", default: "1") == "1"

#let seed = sys.inputs.at("seed", default: none)
#let word = sys.inputs.at("title", default: none)
#let loc = dictionary(locale).at(sys.inputs.at("lang", default: "en") + "-de")
#let loc = if word == none { loc } else {
  loc.with(locale.custom.document(invoice: word))
}

#let look = theme.bold.with(
  if seed != none { theme.custom.brand(color: rgb("#" + seed)) },
  if sys.inputs.at("check", default: "0") == "1" {
    theme.custom.checks(min-contrast: 4.5)
  },
  if with-logo {
    theme.custom.logo(
      image: image("kiln-mark.svg", alt: "Kiln Studio"),
      height: 9mm,
    )
  },
  ..if lay != none { (layout: dictionary(theme.layout).at(lay)) },
)

#show: invoice.with(
  theme: look,
  locale: loc,
  sender: (
    name: "Kiln Studio GmbH",
    address: "Lohmühlenstraße 65",
    city: "12435 Berlin",
    vat-id: "DE318204776",
    register: [Amtsgericht Charlottenburg HRB 214093 B],
    management: [Managing directors: Mira Okafor, Jonas Wendt],
    extra: (Phone: "+49 30 5683 2210", Email: "billing@kiln.studio"),
  ),
  recipient: (
    name: "Halcyon Audio GmbH",
    address: "Attn. Sophie Laurent, Köpenicker Straße 154",
    city: "10997 Berlin",
  ),
  date: datetime(year: 2026, month: 9, day: 21),
  invoice-nr: "KS-26-117",
  customer-nr: "C-0482",
  project: "Halcyon rebrand 2026",
  references: (
    references.project(),
    references.customer-nr(),
    references.vat-id(),
  ),
  zugferd: if sys.inputs.at("zugferd", default: "0") == "1" { "basic" },
)

Hi Sophie, thanks for a brilliant launch! Here is the final invoice, as agreed in our proposal of 2 June 2026.

#let items = (
  item(
    [Discovery workshop],
    quantity: 2,
    unit: unit.day,
    price: 1200,
    description: [Stakeholder interviews, audit, two-day on-site workshop],
  ),
  item([Brand strategy and positioning], price: 3200),
  item(
    [Visual identity system],
    price: 6500,
    description: [Logo suite, grid, iconography, brand guidelines (84 pp.)],
  ),
  item([Typography and colour system], price: 1800),
  item(
    [Motion identity: logo animations],
    quantity: 3,
    unit: unit.piece,
    price: 850,
    description: [Intro, loop and sting, delivered as Lottie and ProRes],
  ),
  item(
    [Packaging design, headphone range],
    quantity: 4,
    unit: unit.piece,
    price: 1150,
  ),
  item(
    [Product photography],
    quantity: 1,
    unit: unit.day,
    price: 1900,
    description: [Studio day, 24 retouched images],
  ),
  item(
    [Image licence, digital and social],
    quantity: 24,
    unit: unit.piece,
    price: 45,
    description: [12 months, worldwide],
  ),
)
#line-items[
  #for it in items.slice(0, calc.min(n, items.len())) { it }
  #discount([Launch package], amount: 5%)
  #if sys.inputs.at("deposit", default: "0") == "1" {
    prepayment(8000, name: [Deposit], date: datetime(
      year: 2026,
      month: 6,
      day: 12,
    ))
  }
]

#payment-terms(days: 21)
#bank-details(
  bank: "GLS Gemeinschaftsbank",
  iban: "DE87100100100912345678",
  bic: "GENODEM1GLS",
)

Questions about this invoice? Write to billing\@kiln.studio - we usually reply within a day.

#signature()
