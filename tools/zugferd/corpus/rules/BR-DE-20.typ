// expect: AGREE_INVALID BR-DE-20
// profiles: xrechnung
//
// An XRechnung collected by SEPA direct debit from a debited account (BT-91)
// with wrong check digits; KoSIT only warns.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-20",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE75512108001245126198",
)
