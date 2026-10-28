// Gallery: `boxed` - an electrician's invoice to a private customer (Handwerk),
// with a site address, a service period, a down payment and the § 35a EStG
// labour note. German locale; layout: auto (a German sender: DIN 5008 A);
// `layout: <name>` swaps the page master.
#import "/src/lib.typ": *

#let gallery(
  layout: auto,
  zugferd: false,
  validation: "draft",
  marker: none,
) = invoice(
  theme: theme.boxed.with(
    theme.custom.logo(
      image: image("brandt.svg", alt: "Elektro Brandt"),
      height: 15mm,
    ),
    layout: if layout == auto { auto } else {
      dictionary(theme.layout).at(layout)
    },
  ),
  locale: locale.de-de,
  validation: validation,
  sender: (
    name: "Elektro Brandt GmbH",
    address: "Werkstraße 7",
    city: "34117 Kassel",
    vat-id: "DE287654321",
    register: [Amtsgericht Kassel, HRB 18432],
    management: [Geschäftsführer: Tobias Brandt],
    extra: (
      Telefon: "0561 470 33 90",
      Notdienst: "0171 470 33 91",
      "E-Mail": "info@elektro-brandt.de",
    ),
  ),
  recipient: (
    name: "Familie Katrin und Jonas Weber",
    address: "Lindenallee 23",
    city: "34131 Kassel",
  ),
  delivery-address: (
    name: "Neubau Weber",
    address: "Am Kirchberg 5",
    city: "34225 Baunatal",
  ),
  invoice-nr: "R-2026-0317",
  customer-nr: "10482",
  order-nr: "A-2026-112 vom 04.08.2026",
  date: datetime(year: 2026, month: 9, day: 21),
  references: (
    references.customer-nr(),
    references.order-nr(label: "Auftrag"),
    references.service-time(label: "Ausführung"),
    references.delivery-address(label: "Leistungsort / Baustelle"),
  ),
  zugferd: if zugferd { "basic" },
  [
    #marker
    Sehr geehrte Frau Weber, sehr geehrter Herr Weber,

    vielen Dank für Ihren Auftrag. Für die Elektroinstallation im Erdgeschoss Ihres Neubaus berechnen wir:

    #line-items[
      #group([Arbeitsleistung])[
        #item(
          [Elektroinstallation Erdgeschoss, Meister],
          quantity: 6.5,
          unit: unit.hour,
          price: 72,
          date: datetime(year: 2026, month: 9, day: 8),
        )
        #item(
          [Elektroinstallation Erdgeschoss, Geselle],
          quantity: 18,
          unit: unit.hour,
          price: 58,
          date: datetime(year: 2026, month: 9, day: 10),
        )
        #item(
          [Prüfung und Messprotokoll nach DIN VDE 0100-600],
          quantity: 1,
          unit: unit.lump-sum,
          price: 145,
          date: datetime(year: 2026, month: 9, day: 12),
        )
        #item(
          [Anfahrt Baustelle Baunatal],
          quantity: 4,
          unit: unit.piece,
          price: 29.5,
        )
      ]
      #group([Material])[
        #item(
          [Mantelleitung NYM-J 3×1,5 mm²],
          quantity: 120,
          unit: unit.metre,
          price: 1.18,
        )
        #item(
          [Mantelleitung NYM-J 5×2,5 mm² (Herd)],
          quantity: 14,
          unit: unit.metre,
          price: 2.95,
        )
        #item(
          [Geräte-Verbindungsdosen, luftdicht],
          quantity: 32,
          unit: unit.piece,
          price: 1.9,
        )
        #item(
          [Schalter und Steckdosen, reinweiß],
          quantity: 21,
          unit: unit.piece,
          price: 14.6,
        )
        #item(
          [FI/LS-Schutzschalter B16, 30 mA],
          quantity: 3,
          unit: unit.piece,
          price: 61.4,
        )
        #item(
          [Unterverteilung Aufputz, 2-reihig],
          description: [24 TE, bestückt und beschriftet, inkl. Überspannungsschutz Typ 2],
          quantity: 1,
          unit: unit.piece,
          price: 189,
        )
      ]
      #item(
        [Entsorgung Verpackung und Altmaterial],
        quantity: 1,
        unit: unit.lump-sum,
        price: 25,
      )
      #prepayment(1500, name: "Abschlag laut Auftrag", date: datetime(
        year: 2026,
        month: 8,
        day: 20,
      ))
    ]

    Im Rechnungsbetrag sind Arbeitskosten (Lohn und Anfahrt) von 1.630,00 € netto enthalten; diese können nach § 35a EStG steuerlich geltend gemacht werden.

    #payment-terms(days: 14)
    #bank-details(
      bank: "Kasseler Sparkasse",
      iban: "DE21520503530001234567",
      bic: "HELADEF1KAS",
    )
    #signature(name: "Tobias Brandt")
  ],
)
