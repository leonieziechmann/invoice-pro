// expect: AGREE_INVALID BR-DE-31
// finding: amounts-payment-means-api-gap
//
// XRechnung requires the debited account (BT-91) of a direct debit.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-LASTSCHRIFT-OHNE-IBAN",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#direct-debit(mandate: "M-2026-017", creditor-id: "DE98ZZZ09999999999")
