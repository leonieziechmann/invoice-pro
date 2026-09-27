// expect: AGREE_INVALID BR-DE-26
// finding: amounts-doctype-gutschrift-written-as-380
//
// A corrected invoice (384) replaces a preceding invoice, which XRechnung
// requires it to name (BR-DE-26). KoSIT only warns, but Mustang rejects it,
// so invoice-pro reports an error.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "corrected",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "R-2026-12-K",
)

#line-items[
  #item([Wartung August], price: 480, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
