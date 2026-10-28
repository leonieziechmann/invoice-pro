// Source: docs/docs/themes/soft.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.soft,
  locale: locale.en-de,
  tax-mode: "inclusive", // consumer prices include VAT
  sender: (
    name: "Lindenblatt Bakery",
    address: "Lindenstraße 8",
    city: "79098 Freiburg",
    vat-id: "DE287654321",
    extra: (Phone: "+49 761 555 38 20", Web: "lindenblatt.de"),
  ),
  recipient: (
    name: "Katharina Sommer",
    address: "Wiesenweg 14",
    city: "79100 Freiburg",
  ),
  invoice-nr: "2026-0381",
  subject: "Catering, birthday brunch on 12 September",
)

#line-items[
  #item([Brunch buffet], quantity: 24, unit: "guests", price: 18.5, tax: 7%)
  #item(
    [Raspberry cream cake],
    quantity: 2,
    unit: unit.piece,
    price: 42,
    tax: 7%,
  )
  #item(
    [Coffee and tea bar],
    quantity: 24,
    unit: "guests",
    price: 3.9,
    tax: 19%,
  )
  #discount([Regular customer discount], amount: 5%)
]

#payment-terms(days: 14)
#bank-details(
  bank: "Sparkasse Freiburg",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Marie Lindner")
