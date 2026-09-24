// expect: AGREE_INVALID BR-CL-08
//
// An invoice note (BT-22) with a subject code (BT-21) outside UNTDID 4451.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  notes: ((text: "Lieferung frei Haus.", subject-code: "XYZ"),),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-08",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
