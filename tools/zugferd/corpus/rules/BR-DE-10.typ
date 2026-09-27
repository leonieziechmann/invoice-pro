// expect: AGREE_INVALID BR-DE-10
// profiles: xrechnung
//
// An XRechnung whose deliver-to address has no city (BT-77).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  delivery-address: (
    name: "Lager Kunde AG",
    address: "Lagerweg 9",
    city: (post-code: "50667"),
  ),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-10",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
