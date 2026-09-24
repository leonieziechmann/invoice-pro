// expect: STRICTER IP-UNIT-02
// finding: core-wrong-rule-ids
//
// A unit given as a text invoice-pro does not know ("Nacht"): the XML would
// state it as "one" (C62), which the validators accept, but which is a
// guess. invoice-pro reported BR-CL-23, which no validator reports for the
// XML; it now reports its own rule.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-UNIT-NACHT",
)

#line-items[
  #item([Hotel], price: 90, quantity: 3, unit: "Nacht", tax: tax.vat(7%))
]
#payment-goal(days: 14)
#bank
