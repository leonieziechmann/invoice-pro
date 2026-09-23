// expect: AGREE_VALID
// finding: tax-default-reason-pdf-xml-divergence
//
// An intra-community supply without own grounds: the XML states a default
// exemption reason (BT-120), so the PDF must print the same statement. The
// PDF printed none (the O-PDF-BT120 oracle checks it).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-K-DEFAULT-REASON",
  tax: tax.intra-community(),
)

#line-items[
  #item([Maschinenteile], price: 1250.00, quantity: 4)
]
#payment-goal(days: 14)
#bank
