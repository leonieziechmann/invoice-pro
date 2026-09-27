// expect: AGREE_VALID
// finding: amounts-doctype-gutschrift-written-as-380
// facts: {"type_code": "384", "invoice_nr": "R-2026-11-K"}
//
// A corrected invoice (384) in XRechnung names the invoice it replaces:
// number (BT-25) and date (BT-26) of the preceding invoice.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "corrected",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "R-2026-11-K",
  preceding-invoice-nr: "R-2026-11",
  preceding-invoice-date: datetime(year: 2026, month: 8, day: 3),
)

#line-items[
  #item([Wartung August], price: 480, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
