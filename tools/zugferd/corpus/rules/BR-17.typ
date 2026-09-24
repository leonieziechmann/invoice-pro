// expect: AGREE_INVALID BR-17
// profiles: basic en16931 xrechnung
//
// A payee (BG-10) with the seller's name: a payee is named only when someone
// other than the seller receives the payment. Not in BASIC WL: the Factur-X
// Schematron compares the payee with a seller path that never matches, so it
// only requires the payee's name there (BR-17--no-name.typ).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  payee: (name: "Muster GmbH"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-17",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
