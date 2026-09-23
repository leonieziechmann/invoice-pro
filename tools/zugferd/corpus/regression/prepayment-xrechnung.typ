// expect: AGREE_INVALID BR-DE-17
// finding: amounts-doctype-gutschrift-written-as-380
//
// XRechnung allows eight document types (BR-DE-17), and a prepayment invoice
// (386) is none of them. KoSIT only warns, but Mustang rejects it, so
// invoice-pro reports an error.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "prepayment",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "AZ-2026-1",
)

#line-items[
  #item([Anzahlung Projekt], price: 1000, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
