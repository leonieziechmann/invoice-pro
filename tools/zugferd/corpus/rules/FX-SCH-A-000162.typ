// expect: AGREE_INVALID FX-SCH-A-000162
// profiles: basic-wl
//
// An invoice note (BT-22) with a subject code (BT-21) outside UNTDID 4451, in
// BASIC WL, whose validation applies the code list of Factur-X alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  notes: ((text: "Lieferung frei Haus.", subject-code: "XYZ"),),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000162",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
