// expect: AGREE_INVALID BR-S-02
// profiles: xrechnung
//
// An XRechnung with standard rated items and a seller without VAT identifier
// or tax number: the XRechnung Schematron reports BR-DE-16, the CEN Schematron
// BR-S-02 for the same violation, which invoice-pro reports.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de-id,
  recipient: buyer-de,
  invoice-nr: "BR-DE-16",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
