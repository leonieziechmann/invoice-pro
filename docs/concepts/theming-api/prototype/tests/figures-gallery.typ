// Figure gallery for the two frozen presets (the other eight live in tests/gallery/):
//   --input preset=classic  a structural engineering office in Munich (de-DE,
//                           HOAI work stages, an interim payment; DIN 5008 A)
//   --input preset=plain    a freelance translator under the small-business rule
//                           (de-DE, § 19 UStG, no logo, no furniture)
#import "/src/lib.typ": *

#let preset = sys.inputs.at("preset", default: "classic")

#let mark = image(
  bytes(
    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 150 40'>"
      + "<rect x='0' y='4' width='32' height='32' fill='#1f4e79'/>"
      + "<path d='M6 30 L16 10 L26 30 Z' fill='none' stroke='white' stroke-width='3'/>"
      + "<line x1='4' y1='30' x2='28' y2='30' stroke='white' stroke-width='3'/>"
      + "<text x='40' y='20' font-family='Liberation Sans, Arial' font-size='15' font-weight='bold' fill='#1f4e79'>HARTMANN</text>"
      + "<text x='40' y='34' font-family='Liberation Sans, Arial' font-size='9' fill='#555555'>INGENIEURBÜRO</text>"
      + "</svg>",
  ),
  format: "svg",
  alt: "Ingenieurbüro Hartmann",
)

#if preset == "classic" [
  #show: invoice.with(
    theme: theme.classic.with(
      theme.custom.brand(color: rgb("#1f4e79")),
      theme.custom.logo(image: mark, height: 11mm),
    ),
    locale: locale.de-de,
    sender: (
      name: "Ingenieurbüro Hartmann PartG mbB",
      address: "Leopoldstraße 88",
      city: "80802 München",
      vat-id: "DE271234567",
      register: [Amtsgericht München PR 2291],
      management: [Partner: Dipl.-Ing. Sven Hartmann, Dr.-Ing. Mira Öztürk],
      extra: (Telefon: "089 2554 1180", "E-Mail": "buero@ib-hartmann.de"),
    ),
    recipient: (
      name: "Wohnbau Isartal GmbH",
      address: "Wolfratshauser Str. 190",
      city: "81479 München",
    ),
    invoice-nr: "2026-117",
    customer-nr: "WI-04",
    project: "Wohnanlage Solln, Haus B",
    date: datetime(year: 2026, month: 9, day: 18),
    references: (
      references.customer-nr(),
      references.project(),
      references.vat-id(),
    ),
  )

  Sehr geehrte Damen und Herren,

  für die Tragwerksplanung der Wohnanlage Solln, Haus B, stellen wir gemäß Ingenieurvertrag vom 12.03.2026 folgende Leistungen in Rechnung:

  #line-items[
    #item(
      [Leistungsphase 3: Entwurfsplanung],
      description: [Statische Berechnung, Positionspläne, Mengenermittlung Beton und Stahl],
      price: 8400,
    )
    #item(
      [Leistungsphase 4: Genehmigungsplanung],
      description: [Prüffähige Statik, Abstimmung mit dem Prüfingenieur],
      price: 5250,
    )
    #item([Brandschutznachweis Tragwerk (R 90)], price: 1380)
    #item([Baustellenbesuche], price: 145, quantity: 6, unit: unit.hour)
    #item([Plotkosten und Vervielfältigung], price: 96.4)
    #prepayment(6000, name: "Abschlagsrechnung 2026-081", date: datetime(
      year: 2026,
      month: 6,
      day: 30,
    ))
  ]

  #payment-terms(days: 30)
  #bank-details(
    bank: "Stadtsparkasse München",
    iban: "DE20701500000012345678",
    bic: "SSKMDEMMXXX",
  )
  #signature(name: "Dipl.-Ing. Sven Hartmann")
] else [
  #show: invoice.with(
    theme: theme.plain,
    locale: locale.de-de,
    tax-exempt-small-biz: true,
    sender: (
      name: "Clara Weiß · Fachübersetzungen",
      address: "Kolberger Straße 4",
      city: "24105 Kiel",
      tax-nr: "20/123/45678",
      email: "post@clara-weiss.de",
    ),
    recipient: (
      name: "Nordwind Reisen GmbH",
      address: "Holstenstraße 21",
      city: "24103 Kiel",
    ),
    invoice-nr: "CW-2026-038",
    date: datetime(year: 2026, month: 9, day: 15),
  )

  Guten Tag Frau Petersen,

  vielen Dank für Ihren Auftrag. Für die Übersetzungen im September berechne ich:

  #line-items[
    #item(
      [Übersetzung Katalog „Skandinavien 2027“],
      description: [Deutsch → Englisch, Normzeilen à 55 Anschläge],
      unit: "Zeilen",
      price: 1.45,
      quantity: 2140,
    )
    #item(
      [Übersetzung AGB, DE → EN (Fachgebiet Recht)],
      price: 1.8,
      quantity: 410,
      unit: "Zeilen",
    )
    #item(
      [Korrektorat Newsletter Oktober],
      price: 55,
      quantity: 2,
      unit: unit.hour,
    )
    #item([Eilzuschlag Katalog (Lieferung in 5 Werktagen)], price: 310)
  ]

  #payment-terms(days: 14)
  #bank-details(
    bank: "Förde Sparkasse",
    iban: "DE68210501700012345678",
    bic: "NOLADE21KIE",
  )
  #signature(name: "Clara Weiß")
]
