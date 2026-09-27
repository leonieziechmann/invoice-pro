// expect: AGREE_INVALID BR-DE-24-b
// profiles: xrechnung
//
// An XRechnung with a payment card and the details of a direct debit (BG-19).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-24-b",
)

#line-items[
  #item-s
]
#payment-goal()
#card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE75512108001245126199",
)
