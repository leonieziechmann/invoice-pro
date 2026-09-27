// expect: AGREE_INVALID BR-S-02
// profiles: basic en16931
//
// Standard rated items (S) on invoice lines without the seller VAT identifier
// (BT-31) or tax number (BT-32).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-S-02",
)

#line-items[
  #item-with(tax.vat(19%))
]
#payment-goal(days: 14)
#bank
