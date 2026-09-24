// expect: AGREE_INVALID FX-SCH-A-000031
// profiles: minimum basic-wl
//
// A seller legal registration identifier (BT-30) with a scheme that is no
// ISO/IEC 6523 code, in the profiles whose validation applies the code lists
// of Factur-X alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de + (legal-id: id.custom("9999", "4711")),
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000031",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
