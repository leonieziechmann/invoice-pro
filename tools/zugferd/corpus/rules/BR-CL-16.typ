// expect: AGREE_INVALID BR-CL-16
// profiles: basic en16931 xrechnung
//
// A payment means code (BT-81) outside UNTDID 4461.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-16",
)

#line-items[
  #item-s
]
#paid(method: (code: "999", name: [Tausch]))
