// expect: AGREE_VALID
// finding: amounts-payment-means-api-gap
// facts: {"payment_means": ["54"], "card": ["1234", "Erika Kunde"], "paid": true}
//
// An XRechnung paid by credit card when it was issued. It was reported as
// BR-DE-1, and the hint asked for bank details, which would have stated a
// credit transfer (58) for an invoice that is paid.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-KARTE-BEZAHLT",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#paid(method: "card", date: datetime(year: 2026, month: 9, day: 1))
#card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")
