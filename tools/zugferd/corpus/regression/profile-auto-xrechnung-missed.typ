// expect: AGREE_VALID
// warns: BR-DE-1
// finding: o-registry-auto-fallback
//
// `zugferd: auto` for a buyer in Germany without payment instructions:
// XRechnung requires them (BR-DE-1), so the invoice is an EN 16931 invoice,
// which lists the rule of XRechnung it missed as a warning. That rule is no
// rule of EN 16931 in the rule registry: the runner's registry check
// (O-REGISTRY) accepts it as a warning of the profile the invoice missed.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: auto,
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-AUTO-OHNE-ZAHLUNGSWEG",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
