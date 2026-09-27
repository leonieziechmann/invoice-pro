// expect: AGREE_INVALID FX-SCH-A-000036
// profiles: minimum basic-wl
//
// A seller country code (BT-40) outside ISO 3166-1, in the profiles whose
// validation applies the code list of Factur-X alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de + (country: "XX"),
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000036",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
