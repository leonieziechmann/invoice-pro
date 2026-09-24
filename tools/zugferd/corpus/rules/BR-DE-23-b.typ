// expect: AGREE_INVALID BR-DE-23-b
//
// An XRechnung with a credit transfer and the details of a direct debit
// (BG-19).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-23-b",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE75512108001245126199",
)
