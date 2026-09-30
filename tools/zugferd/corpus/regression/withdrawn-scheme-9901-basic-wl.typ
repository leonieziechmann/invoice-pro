// expect: AGREE_INVALID FX-SCH-A-000429
// finding: core-wrong-rule-ids
//
// A buyer electronic address (BT-49) with the scheme 9901, which the EAS code
// lists have withdrawn. Mustang 2.14.0 validated BASIC WL with a Factur-X
// list that still had it, so invoice-pro reported its own IP-CODE-01; the
// Factur-X 1.09 list of Mustang 2.26.0 lacks it as well, so it is the rule of
// the Factur-X Schematron of the position.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: (scheme: "9901", id: "12345678")),
  invoice-nr: "RG-SCHEME-9901-BWL",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
