// expect: AGREE_INVALID BR-E-02
// profiles: basic en16931 xrechnung
//
// Exempt items (E) on invoice lines without the seller VAT identifier (BT-31)
// or tax number (BT-32).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-E-02",
)

#line-items[
  #item-with(tax.exempt(grounds: "Steuerfrei nach § 4 Nr. 14 UStG"))
]
#payment-goal(days: 14)
#bank
