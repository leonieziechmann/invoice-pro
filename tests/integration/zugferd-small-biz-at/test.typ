// Austrian small business (§ 6 Abs. 1 Z 27 UStG, VAT category E) that
// states only its tax number (BT-32, BR-E-02). Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-at,
  zugferd: "en16931",
  tax-exempt-small-biz: true,
  sender: (
    name: "Anna Muster Grafik",
    address: "Mariahilfer Straße 1",
    city: (name: "Wien", post-code: "1060"),
    country: country.at,
    tax-nr: "12 345/6789",
    contact: (
      name: "Anna Muster",
      phone: "+43 1 1234567",
      email: "rechnung@muster-grafik.at",
    ),
  ),
  recipient: (
    name: "Kunde GmbH",
    address: "Herrengasse 7",
    city: (name: "Graz", post-code: "8010"),
    country: country.at,
    vat-id: "ATU87654321",
  ),
  invoice-nr: "KU-2026-018",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Logo-Entwurf], price: 450.00)
  #item([Visitenkarten], price: 0.35, quantity: 500, unit: unit.piece)
]

#payment-goal(days: 14)

#bank-details(
  bank: "Musterbank",
  iban: "AT611904300234573201",
  bic: "BKAUATWWXXX",
)
