// expect: AGREE_VALID
// finding: amounts-delivery-date-mismatch
// facts: {"period": ["20260801", "20260831"]}
//
// One item dated with the period of August and one without a date: the
// invoicing period (BG-14) is August, as printed by
// `references.service-time()`. The undated item used to add the invoice
// date (1 September) to the XML only.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-PERIOD-MIXED",
  references: (references.service-time(),),
)

#line-items[
  #item(
    [Wartung August],
    price: 300,
    tax: tax.vat(19%),
    date: (
      datetime(year: 2026, month: 8, day: 1),
      datetime(year: 2026, month: 8, day: 31),
    ),
  )
  #item([Material], price: 40, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
