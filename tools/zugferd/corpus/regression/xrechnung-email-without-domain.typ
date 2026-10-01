// expect: AGREE_VALID
// warns: BR-DE-28
// finding: fidelity-cat-xr-warning-rules
//
// XRechnung: the seller e-mail address must match the official pattern
// (BR-DE-28). An address without a domain name fails the patterns of both
// XRechnung Schematron versions (unlike the domain with umlauts of
// xrechnung-idn-email, which both accept). Both validators only warn, and
// so does invoice-pro (Mustang 2.14.0 reported an error).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de
    + (
      contact: (
        name: "Max Muster",
        phone: "+49 30 1234567",
        email: "rechnung@muster",
      ),
    ),
  recipient: buyer-de,
  invoice-nr: "RG-XR-EMAIL-DOMAIN",
)

#line-items[
  #item([Ware], price: 100, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
