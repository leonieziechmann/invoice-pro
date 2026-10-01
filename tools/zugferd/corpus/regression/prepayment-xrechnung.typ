// expect: AGREE_VALID
// warns: BR-DE-17
// finding: amounts-doctype-gutschrift-written-as-380
//
// XRechnung allows eight document types (BR-DE-17), and a prepayment invoice
// (386) is none of them. Both validators only warn (Mustang
// 2.14.0 reported an error), and so does invoice-pro.

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
