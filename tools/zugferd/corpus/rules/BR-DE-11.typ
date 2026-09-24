// expect: AGREE_INVALID BR-DE-11
//
// An XRechnung whose deliver-to address has no post code (BT-78).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  delivery-address: (
    name: "Lager Kunde AG",
    address: "Lagerweg 9",
    city: "Köln",
  ),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-11",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
