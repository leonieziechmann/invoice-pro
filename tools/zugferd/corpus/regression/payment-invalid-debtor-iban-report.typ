// expect: AGREE_INVALID BR-DE-20
// finding: amounts-payment-means-api-gap
//
// The debited account of a SEPA direct debit must be a valid IBAN in
// XRechnung (BR-DE-20).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-LASTSCHRIFT-IBAN",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#direct-debit(mandate: "M-2026-017", creditor-id: "DE98ZZZ09999999999", debtor-iban: "DE00120300000000202051")
