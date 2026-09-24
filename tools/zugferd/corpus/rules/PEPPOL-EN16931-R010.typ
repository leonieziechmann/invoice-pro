// expect: AGREE_INVALID PEPPOL-EN16931-R010
// profiles: xrechnung
//
// An XRechnung whose buyer has no electronic address (BT-49), and no VAT
// identifier or email address to derive it from.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de + (vat-id: none, email: none),
  invoice-nr: "PEPPOL-EN16931-R010",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
