// expect: AGREE_INVALID BR-02
//
// An invoice without an invoice number (BT-1).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
)

#line-items[#item-s]
#payment-goal(days: 14)
#bank
