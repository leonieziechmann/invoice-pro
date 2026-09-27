// expect: AGREE_INVALID FX-SCH-A-000179
// profiles: basic-wl
//
// A VAT category (BT-118) outside the code list of Factur-X (AA), in BASIC
// WL, whose validation applies it alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000179",
)

#line-items[
  #item-with(tax.new(rate: 7%, category: "AA"))
]
#payment-goal(days: 14)
#bank
