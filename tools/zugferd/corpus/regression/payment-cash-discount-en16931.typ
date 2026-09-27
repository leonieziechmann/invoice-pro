// expect: AGREE_VALID
// finding: amounts-skonto-br-de-18-false-negative
// facts: {"payment_terms": "Bei Zahlung innerhalb von 14 Tagen gewähren wir 2% Skonto.\nBei Zahlung innerhalb von 7 Tagen gewähren wir 3% Skonto auf 1.190,00 €."}
//
// Outside XRechnung, the payment terms state the cash discounts as the
// invoice prints them.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-SKONTO-EN",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(
  days: 30,
  discount: (
    (days: 14, percent: 2%),
    (days: 7, percent: 3%, basis: 1190),
  ),
)
#bank
