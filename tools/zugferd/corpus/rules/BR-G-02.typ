// expect: AGREE_INVALID BR-G-02
// profiles: basic en16931 xrechnung
//
// An export outside the EU (G) on invoice lines without the seller VAT
// identifier (BT-31); its tax number does not do.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-us,
  invoice-nr: "BR-G-02",
)

#line-items[
  #item-with(tax.export())
]
#payment-goal(days: 14)
#bank
