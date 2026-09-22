// Gallery: `prestige` - a boutique hotel's guest folio in English (sender in
// Vienna, locale en-at): a three-night stay grouped as one stay, split VAT (10 %
// lodging and food, 20 % drinks and spa), a courtesy discount on the spa and a
// deposit already received. Default layout: layout: auto (a4-band).
//   typst compile --root . tests/gallery/prestige.typ out/gallery-prestige-{p}.png --ppi 110
//   --input layout=<name>   another layout (default: the preset's choice)
//   --input logo=light|plate|none  light (default): the dark mark plus a champagne
//                           on-dark version; plate: only the dark mark (it gets the
//                           light plate on the band); none: no logo
//   --input zugferd=1  --input extra=<n> (more in-room dining lines)  --input level=..
#import "/src/lib.typ": *

#let lay = sys.inputs.at("layout", default: none)
#let logo-mode = sys.inputs.at("logo", default: "light")
#let extra = int(sys.inputs.at("extra", default: "0"))
#let level = sys.inputs.at("level", default: "draft")

#let mark = image("pa-mark.svg", alt: "Palais Aurelia")
#let logo = if logo-mode == "light" {
  theme.custom.logo(image: mark, height: 13mm, on-dark: image(
    "pa-mark-light.svg",
    alt: "Palais Aurelia",
  ))
} else if logo-mode == "plate" { theme.custom.logo(image: mark, height: 13mm) }

#let nights = (display: "nights", code: "DAY")
#let covers = (display: "covers", code: "C62")
#let service = (display: "", code: "C62") // one service: no unit word
#let lux-item = item.with(unit: service)

#show: invoice.with(
  theme: theme.prestige.with(
    logo,
    theme.custom.checks(min-contrast: 4.5),
    ..if lay != none { (layout: dictionary(theme.layout).at(lay)) },
  ),
  locale: locale.en-at,
  validation: if level == "none" { none } else { level },
  sender: (
    name: "Palais Aurelia",
    address: "Seilerstätte 9",
    city: "1010 Vienna",
    vat-id: "ATU73194628",
    register: [Aurelia Hotelbetriebs GmbH · FN 482117 k · Commercial Court Vienna],
    management: [Managing Director: Clémence Aubry],
    extra: (Phone: "+43 1 512 94 00", "E-Mail": "reception@palais-aurelia.at"),
  ),
  recipient: (
    name: "Ms Eleanor Whitcombe",
    address: "14 Cheyne Walk",
    city: "London SW3 5HL, United Kingdom",
  ),
  invoice-nr: "F-2026-0917",
  customer-nr: "G-58214",
  order-nr: "RES-771402",
  references: (
    references.customer-nr(label: "Guest No."),
    references.order-nr(label: "Reservation"),
    references.vat-id(),
  ),
  date: datetime(year: 2026, month: 9, day: 15),
  subject: "Guest Folio",
  tax-mode: "inclusive",
  zugferd: if sys.inputs.at("zugferd", default: "0") == "1" { "basic" },
)

Dear Ms Whitcombe, thank you for staying with us. Please find the details of your stay below.

#line-items[
  #group([Suite Belvedere · 12 – 15 September 2026])[
    #item(
      [Suite Belvedere, park view],
      description: [Three nights, double occupancy],
      quantity: 3,
      unit: nights,
      price: 890,
      tax: 10%,
    )
    #item(
      [Breakfast in the Salon Rouge],
      quantity: 6,
      unit: covers,
      price: 42,
      tax: 10%,
    )
    #lux-item(
      [Dinner, Restaurant Aurelia],
      description: [Seven-course tasting menu for two],
      price: 396,
      tax: 10%,
    )
    #lux-item(
      [Wine pairing, Restaurant Aurelia],
      description: [Grüner Veltliner Smaragd 2019, Blaufränkisch Reserve 2017],
      price: 188,
      tax: 20%,
    )
    #lux-item(
      [Signature massage, 90 min],
      quantity: 2,
      price: 210,
      tax: 20%,
      modifier: discount([Returning guest courtesy], amount: 10%),
    )
    #lux-item([Airport transfer, Mercedes S-Class], price: 145, tax: 10%)
    #lux-item([Laundry and pressing service], price: 64, tax: 20%)
    #for i in range(extra) {
      lux-item([In-room dining, order #(i + 1)], price: 38, tax: 20%)
    }
  ]
  #prepayment(1000, name: [Deposit], date: [28 August 2026])
]

#payment-terms(days: 14)
#bank-details(
  bank: "Erste Bank der oesterreichischen Sparkassen",
  iban: "AT242011182221219800",
  bic: "GIBAATWWXXX",
)

We look forward to welcoming you again.
// a folio carries no signature; a long one (extra lines) closes with one
#if extra > 0 { signature() }
