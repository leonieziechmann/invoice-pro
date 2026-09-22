// compat-014: bench-150 with a variable item count (--input n=1|150|400).
#import "/src/lib.typ": *
#let n = int(sys.inputs.at("n", default: "150"))
#show: invoice.with(
  theme: theme.classic,
  locale: locale.de-de,
  sender: (
    name: "Nordlicht Studio GmbH",
    address: "Hafenstrasse 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acme Maschinenbau AG",
    address: "Industriestrasse 5",
    city: "70173 Stuttgart",
  ),
  invoice-nr: "2026-0815",
)
#line-items[
  #for i in range(n) { item([Item #i], description: [Desc], price: 10 + i) }
  #group([G])[#item([a], price: 1) #item([b], price: 2)]
]
#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature()
