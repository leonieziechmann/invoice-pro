// expect: AGREE_INVALID BR-DE-28
// finding: fidelity-cat-xr-warning-rules
//
// XRechnung: the seller e-mail address must match the official pattern
// (BR-DE-28), which has no internationalized domains (use punycode). It was
// a warning, invisible in the default mode.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de
    + (
      contact: (
        name: "Max Müller",
        phone: "+49 89 1234567",
        email: "info@müller-bau.de",
      ),
    ),
  recipient: buyer-de,
  invoice-nr: "RG-XR-EMAIL",
)

#line-items[
  #item([Ware], price: 100, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
