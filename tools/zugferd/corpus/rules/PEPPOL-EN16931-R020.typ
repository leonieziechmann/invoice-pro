// expect: AGREE_INVALID PEPPOL-EN16931-R020 BR-DE-7
// profiles: xrechnung
//
// An XRechnung whose seller has no electronic address (BT-34), and neither a
// VAT identifier nor a contact email address to derive it from; the missing
// email address of the contact breaks BR-DE-7 as well.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de
    + (vat-id: none, contact: (name: "Max Muster", phone: "+49 30 1234567")),
  recipient: buyer-de,
  invoice-nr: "PEPPOL-EN16931-R020",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
