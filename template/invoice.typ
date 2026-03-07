#import "@preview/invoice-pro:0.2.0": *

#let item-discount(name, amount: 0%, description: none) = (
  (name: name, amount: -amount, description: description),
)

#show: invoice()

#line-items[
  #bundle(
    date: (date(10, 2, 2026), date(5, 3, 2026)),
  )[Webseiten Relaunch 2026][
    #item(
      price: 1200.00,
      quantity: 1,
      unit: "Pauschale",
    )[Konzeption & Wireframing]
    #item(price: 85.00, quantity: 15, unit: "Std.")[UI/UX Design]
    #item(
      price: 95.00,
      quantity: 40,
      unit: "Std.",
    )[Frontend & Backend Entwicklung]

    #modifier(amount: -10%)[Paketrabatt (10% auf Entwicklungsleistungen)]

    #bundle[SEO & Tracking Setup][
      #item(
        price: 90.00,
        quantity: 5,
        unit: "Std.",
      )[Keyword-Recherche & Strategie]
      #item(price: 150.00, quantity: 1)[Setup Google Analytics & Tag Manager]
    ]
  ]

  #apply(tax: tax.vat(7%), modifier: item-discount(
    amount: 15%,
  )[Frühbucherrabatt])[
    #item(
      price: 49.90,
      quantity: 2,
      unit: "Stk.",
    )[Fachbuch: "Modernes Webdesign"]
    #item(price: 29.90, quantity: 1, unit: "Stk.")[Fachbuch: "SEO für Anfänger"]
  ]

  #item(
    price: 15.00,
    quantity: 12,
    unit: "Monate",
    date: datetime.today(),
  )[Premium Hosting]

  #item(total: 11.90, input-gross: true)[Domainregistrierung (.de)]

  #item(
    price: 0,
    tax: tax.zero(),
    description: "Inklusivleistung gemäß Rahmenvertrag",
  )[Einrichtung der E-Mail-Postfächer]

  #modifier(amount: -50)[Aktionsgutschein "NEUKUNDE50"]
  #modifier(amount: 15.00)[Bearbeitungs- und Servicegebühr]
  #modifier(amount: -3%)[Skonto (bei Zahlung innerhalb von 7 Tagen)]
]

#pagebreak()







#line-items(tax-mode: "exclusive", tax: tax.vat(19%))[
  #bundle[Dienstreise Berlin][
    #item(price: 120.00, quantity: 2, tax: tax.vat(7%), date: date(
      12,
      5,
      2026,
    ))[Hotelübernachtung]
    #item(price: 85.50, quantity: 1, tax: tax.vat(19%), date: date(
      14,
      5,
      2026,
    ))[Bahnticket]
  ]

  #bundle(
    description: "Individuell vereinbartes Catering-Paket laut Angebot",
    date: date(20, 5, 2026),
  )[Messecatering][
    #item(price: 25.00, quantity: 50, tax: tax.vat(19%), date: date(
      20,
      5,
      2026,
    ))[Buffet Standard]
    #item(price: 4.50, quantity: 50, tax: tax.vat(19%), date: date(
      20,
      5,
      2026,
    ))[Getränkepauschale]
  ]

  #for i in range(1, 4) {
    item(
      price: 15.00,
      description: [Lizenzschlüssel für Arbeitsplatz #i],
    )[Software-Abonnement (Monat)]
  }

  #item(
    price: 12.00,
    quantity: 250,
    base-quantity: 100,
    unit: "Stk.",
  )[Flyer Druck (Preis pro 100 Stk.)]

  #bundle(quantity: 3, base-quantity: 1, unit: "Paket")[Social Media Kampagne][
    #item(price: 150.00)[Kampagnen-Setup]
    #item(price: 50.00)[Grafik-Erstellung]
  ]

  #item(
    total: 450.00,
    quantity: 6,
    unit: "Std.",
    description: "Einzelpreis wurde automatisch via Total errechnet",
  )[Notdienst-Pauschale]
]
