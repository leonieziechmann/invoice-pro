// expect: AGREE_VALID
// finding: amounts-delivery-date-mismatch
// facts: {"period": ["20260601", "20260630"]}
//
// The service period of the invoice (`service-period`), without dates on the
// items: printed by `references.service-time()` and written as the invoicing
// period (BG-14) instead of the invoice date.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PERIOD-INVOICE",
  service-period: (
    datetime(year: 2026, month: 6, day: 1),
    datetime(year: 2026, month: 6, day: 30),
  ),
  references: (references.invoice-nr(), references.service-time()),
)

#line-items[
  #item([Projektberatung Juni], quantity: 15, unit: unit.hour, price: 120)
]
#payment-goal(days: 14)
#bank
