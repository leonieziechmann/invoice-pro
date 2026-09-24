// expect: AGREE_INVALID BR-AG-02
// profiles: basic en16931 xrechnung
//
// IPSI items (M) on invoice lines without the seller VAT identifier (BT-31) or
// tax number (BT-32).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-02",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(4%))
]
#payment-goal(days: 14)
#bank
