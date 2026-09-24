// expect: AGREE_INVALID BR-02
// profiles: minimum basic-wl basic en16931 xrechnung
//
// An invoice without an invoice number (BT-1).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
