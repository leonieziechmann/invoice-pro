// expect: STRICTER IP-VAT-226
// finding: robustness-basic-wl-ae-k-stricter, fidelity-cat-basicwl-line-rules
//
// BASIC WL has no line-level category rules, so the official validators
// accept reverse charge without the buyer VAT identifier. The law requires it
// (Art. 226 VAT Directive): invoice-pro reports its own rule IP-VAT-226
// (maintainer decision), not the EN 16931 rule BR-AE-02 the profile lacks.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "RG-BWL-AE",
)

#line-items[
  #item([Montage], price: 100, quantity: 1, tax: tax.reverse-charge())
]
#payment-goal(days: 14)
#bank
