// expect: AGREE_VALID
// profiles: xrechnung
//
// A domestic Italian invoice with the split payment of Italy (B) only, which
// the validation of XRechnung accepts.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-it,
  recipient: buyer-it,
  invoice-nr: "BR-B-01--pass",
)

#line-items[
  #item-with(tax.special.transferred(22%))
]
#payment-goal(days: 14)
#bank
