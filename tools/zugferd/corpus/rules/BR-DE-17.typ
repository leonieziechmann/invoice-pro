// expect: AGREE_INVALID BR-DE-17
// profiles: xrechnung
//
// XRechnung has no prepayment invoice (BT-3 = 386); KoSIT only warns (see
// tools/zugferd/validator-differences.toml).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  document-type: "prepayment",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-17",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
