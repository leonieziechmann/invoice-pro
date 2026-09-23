// expect: STRICTER IP-DOC-03
// finding: amounts-doctype-gutschrift-written-as-380
//
// A credit note states the credited amounts as positive amounts. With
// negative prices, the credit note (381) would ask the buyer to pay, which
// the official validators accept.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  document-type: "credit-note",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RK-2026-18",
  due-date: "Der Betrag wird mit Ihrer nächsten Rechnung verrechnet.",
)

#line-items[
  #item([Bonus 2026], price: -500, quantity: 1, tax: tax.vat(19%))
]
#bank-details(bank: "Kundenbank", iban: "DE75512108001245126199")
