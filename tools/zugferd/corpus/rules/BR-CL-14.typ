// expect: AGREE_INVALID BR-CL-14
//
// A buyer country code (BT-55) outside ISO 3166-1.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (country: "XX"),
  invoice-nr: "BR-CL-14",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
