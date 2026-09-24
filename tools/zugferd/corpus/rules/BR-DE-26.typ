// expect: AGREE_INVALID BR-DE-26
//
// A corrected invoice (BT-3 = 384) in XRechnung that names no preceding
// invoice (BG-3); KoSIT only warns.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "corrected",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-26",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
