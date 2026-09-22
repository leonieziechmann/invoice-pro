// Gallery: `elegant` for a law and tax partnership (de-DE, hourly fees in two
// mandate groups plus disbursements). Default layout: layout: auto (German
// sender -> DIN 5008 form B for this preset).
//   typst compile --root . tests/gallery/elegant.typ out/gallery-elegant-{p}.png --ppi 110
//   --input layout=<name>   render on another layout (default: the preset's choice)
//   --input logo=1          add the monogram (image with alt text, for ua-1)
//   --input zugferd=1       attach ZUGFeRD (compile with --pdf-standard a-3b)
//   --input extra=<n>       n additional hourly items (multi-page invoice)
//   --input level=draft|strict|none   validation level (default draft)
#import "/src/lib.typ": *

#let lay = sys.inputs.at("layout", default: none)
#let with-logo = sys.inputs.at("logo", default: "0") == "1"
#let extra = int(sys.inputs.at("extra", default: "0"))
#let level = sys.inputs.at("level", default: "draft")

#let look = theme.elegant.with(
  theme.custom.checks(min-contrast: 4.5),
  if with-logo {
    theme.custom.logo(image: image("hk-mark.svg", alt: "Hartmann & Kollegen"))
  },
  ..if lay != none { (layout: dictionary(theme.layout).at(lay)) },
)

#show: invoice.with(
  theme: look,
  locale: locale.de-de,
  validation: if level == "none" { none } else { level },
  sender: (
    name: "Hartmann & Kollegen",
    address: "Prinzregentenstraße 54",
    city: "80538 München",
    vat-id: "DE281734905",
    tax-nr: "143/218/60417",
    register: [PartG mbB · AG München PR 1294],
    management: [Partner: Dr. J. Hartmann, F. Kranz],
    extra: (
      Telefon: "+49 89 2154 880",
      "E-Mail": "kanzlei@hartmann-kollegen.de",
    ),
  ),
  recipient: (
    name: "Brenner Maschinenbau GmbH",
    address: "Industriestraße 40",
    city: "86159 Augsburg",
  ),
  date: datetime(year: 2026, month: 9, day: 18),
  invoice-nr: "HK-2026-0318",
  customer-nr: "M-4471",
  project: "Umstrukturierung Brenner-Gruppe",
  subject: "Honorarrechnung Juli bis September 2026",
  references: (
    references.customer-nr(),
    references.project(),
    references.vat-id(),
    references.tax-nr(),
  ),
  zugferd: if sys.inputs.at("zugferd", default: "0") == "1" { "basic" },
)

Sehr geehrter Herr Dr. Brenner,

für unsere Tätigkeit im Mandat „Umstrukturierung Brenner-Gruppe“ im Zeitraum Juli bis September 2026 erlauben wir uns, gemäß Vergütungsvereinbarung vom 3. Juli 2026 wie folgt abzurechnen:

#line-items[
  #group(
    [Gesellschaftsrecht],
    description: [Verschmelzung der Brenner Service GmbH auf die Brenner Maschinenbau GmbH],
  )[
    #item(
      [Erstberatung und Sachverhaltsaufnahme],
      quantity: 2.5,
      unit: unit.hour,
      price: 340,
    )
    #item(
      [Prüfung Gesellschaftsvertrag und Geschäftsordnung],
      quantity: 6,
      unit: unit.hour,
      price: 340,
      description: [inkl. Satzungsänderungen seit 2019],
    )
    #item(
      [Entwurf Verschmelzungsvertrag und -bericht],
      quantity: 11.5,
      unit: unit.hour,
      price: 340,
    )
    #item(
      [Abstimmung mit Notariat und Registergericht],
      quantity: 3,
      unit: unit.hour,
      price: 340,
    )
    #item(
      [Teilnahme an der Gesellschafterversammlung],
      quantity: 4,
      unit: unit.hour,
      price: 340,
      description: [Augsburg, 11. September 2026, inkl. Vorbereitung],
    )
  ]
  #group([Steuerliche Begleitung])[
    #item(
      [Steuerliche Würdigung nach § 20 UmwStG],
      quantity: 5.5,
      unit: unit.hour,
      price: 290,
    )
    #item(
      [Antrag auf verbindliche Auskunft],
      quantity: 7,
      unit: unit.hour,
      price: 290,
      description: [Entwurf, Abstimmung mit der Mandantin, Einreichung beim Finanzamt Augsburg-Stadt],
    )
    #for i in range(extra) {
      item(
        [Telefonische Abstimmung mit der Mandantin (#(i + 1))],
        quantity: 0.5,
        unit: unit.hour,
        price: 290,
      )
    }
  ]
  #item(
    [Reisekosten München–Augsburg],
    quantity: 1,
    unit: unit.flat,
    price: 148.60,
    description: [Bahn, 1. Klasse, Hin- und Rückfahrt],
  )
  #item(
    [Auslagenpauschale Post und Telekommunikation],
    quantity: 1,
    unit: unit.flat,
    price: 20,
  )
]

#payment-terms(days: 14)
#bank-details(
  bank: "Bayerische Landesbank",
  iban: "DE72700500000004567812",
  bic: "BYLADEMMXXX",
)

Für Rückfragen zu dieser Rechnung steht Ihnen Frau Dr. Hartmann gerne zur Verfügung.

#signature()
