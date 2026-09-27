// Source: docs/docs/b2b.md — "2. Cross-Border B2B Invoice (Reverse Charge)"
// Compile-only: the example must compile as documented (it used to
// carry an invalid IBAN).
#import "/src/lib.typ": *

#show: invoice.with(
  locale: locale.en-de,
  // We use the reverse-charge tax helper which automatically assigns
  // the correct tax category for e-invoicing and displays standard reverse charge terms.
  tax: tax.reverse-charge(),

  sender: (
    name: "Creative Studio GmbH",
    address: "Designer Weg 5",
    city: "10115 Berlin",
    country: country.de,
    vat-id: "DE123456789", // Mandatory for intra-community supplies
  ),

  recipient: (
    name: "Acme Paris SAS",
    address: "Rue de la Paix 15",
    city: "75002 Paris",
    country: country.fr,
    vat-id: "FR99123456789", // Recipient VAT ID is mandatory to justify Reverse Charge
  ),

  invoice-nr: "INV-2026-0090",
  date: datetime(year: 2026, month: 7, day: 9),
  references: (
    "Performance Period": "01.06.2026 - 30.06.2026",
    "Customer ID": "CUST-PARIS-02",
  ),
)

= UI/UX Redesign Services

#line-items[
  #item([Wireframe & Prototyping], quantity: 20, unit: unit.hour, price: 85.00)
  #item([User Research Sessions], quantity: 8, unit: unit.hour, price: 100.00)
]

#payment-goal(days: 30)

#bank-details(
  bank: "Commerzbank Berlin",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
