// expect: AGREE_INVALID BR-63
// finding: core-wrong-rule-ids
//
// A buyer electronic address without a scheme violates BR-63; invoice-pro
// reported it as BR-CL-25 (unknown scheme), which the official validators do
// not name.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: "4000001123452"),
  invoice-nr: "RG-EADDR-SCHEME",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
