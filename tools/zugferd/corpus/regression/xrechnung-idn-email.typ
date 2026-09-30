// expect: AGREE_VALID
// finding: fidelity-cat-xr-warning-rules
//
// XRechnung: a seller e-mail address with an internationalized domain. The
// pattern of the XRechnung Schematron 3.0.2 (BR-DE-28, a warning) accepts
// it, and so does invoice-pro; the older pattern of Mustang 2.14.0 had ASCII
// characters only.

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
