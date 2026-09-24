// expect: AGREE_INVALID FX-SCH-A-000040
// profiles: minimum basic-wl
//
// An invoice currency (BT-5) that is no ISO 4217 code, in the profiles whose
// validation applies the code list of Factur-X alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  currency: "ABC",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000040",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
