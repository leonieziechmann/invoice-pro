// expect: AGREE_VALID
// profiles: xrechnung
//
// An XRechnung whose buyer electronic address (BT-49) has the scheme 0219,
// which the EAS code lists of EN 16931 have: the validation of XRechnung
// applies them alone (not the Factur-X list, which lacks it,
// FX-SCH-A-000031--0219.typ).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de + (electronic-address: (scheme: "0219", id: "4711")),
  invoice-nr: "BR-CL-25--pass",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
