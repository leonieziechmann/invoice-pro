// expect: AGREE_INVALID BR-16
//
// An invoice without lines (BG-25).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-16",
)

#line-items[]
#payment-goal(days: 14)
#bank
