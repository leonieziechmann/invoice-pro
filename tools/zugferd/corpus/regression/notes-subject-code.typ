// expect: AGREE_INVALID BR-CL-08
// finding: amounts-minor-reference-gaps
//
// The subject code of a note (BT-21) must be a code of UNTDID 4451.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-NOTES-CODE",
  notes: ((text: "Lieferung frei Haus.", subject-code: "XYZ"),),
)

#line-items[
  #item([Wartung August], price: 480, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
