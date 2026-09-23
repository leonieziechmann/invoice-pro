// French franchise en base de TVA (art. 293 B du CGI, VAT category E) in the
// BASIC WL profile, with a document level discount. The micro-entrepreneur
// has no VAT identifier and states its SIREN as tax registration (BT-32),
// which an exempt invoice needs (BR-E-02, BR-E-03). Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.fr-fr,
  zugferd: "basic-wl",
  tax-exempt-small-biz: true,
  sender: (
    name: "Anne Martin Traduction",
    address: "1 rue de Rivoli",
    city: (name: "Paris", post-code: "75001"),
    country: country.fr,
    tax-nr: "303265045",
    contact: (
      name: "Anne Martin",
      phone: "+33 1 23456789",
      email: "facturation@martin-traduction.fr",
    ),
  ),
  recipient: (
    name: "Client SAS",
    address: "10 avenue Foch",
    city: (name: "Lyon", post-code: "69001"),
    country: country.fr,
    vat-id: "FR61954506077",
  ),
  invoice-nr: "KU-2026-019",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Traduction], price: 0.12, quantity: 4000)
  #item([Relecture], price: 45.00, quantity: 3, unit: unit.hour)

  #discount([Remise fidélité], amount: 5%)
]

#payment-goal(days: 30)

#bank-details(
  bank: "Banque Exemple",
  iban: "FR1420041010050500013M02606",
  bic: "PSSTFRPPPAR",
)
