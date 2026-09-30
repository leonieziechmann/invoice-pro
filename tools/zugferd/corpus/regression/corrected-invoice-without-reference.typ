// expect: STRICTER IP-DOC-02
// finding: amounts-doctype-gutschrift-written-as-380
//
// A corrected invoice (384) replaces a preceding invoice, which it must name
// (Art. 219 of the VAT Directive). The validators only warn (XRechnung's
// BR-DE-26), so invoice-pro reports its own rule as an error.

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
