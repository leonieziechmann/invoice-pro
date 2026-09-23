// expect: AGREE_INVALID BR-DE-23-b
// finding: amounts-payment-means-api-gap
// facts: {"payment_means": ["58", "59"]}
//
// Bank details next to a direct debit: two payment means, of which
// XRechnung forbids the direct debit next to a credit transfer
// (BR-DE-23-b). The buyer could pay twice.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-LASTSCHRIFT-UND-KONTO",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
#bank
