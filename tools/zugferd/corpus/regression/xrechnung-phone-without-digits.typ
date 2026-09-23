// expect: AGREE_INVALID BR-DE-27
// finding: fidelity-cat-xr-warning-rules
//
// XRechnung: a seller phone number needs at least three digits (BR-DE-27).
// invoice-pro treats it as an error, like Mustang (KoSIT only warns). It was
// a warning, invisible in the default mode.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de
    + (
      contact: (
        name: "Max Muster",
        phone: "Zentrale",
        email: "rechnung@muster.example",
      ),
    ),
  recipient: buyer-de,
  invoice-nr: "RG-XR-PHONE",
)

#line-items[
  #item([Ware], price: 100, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
