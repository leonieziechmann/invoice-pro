// expect: AGREE_INVALID PEPPOL-EN16931-R111
// finding: amounts-minor-reference-gaps
//
// The service period of the invoice (`service-period`, BG-14) ends before
// the period of an item (BG-26): XRechnung requires the lines within the
// invoicing period.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-ITEM-PERIOD",
  service-period: (
    datetime(year: 2026, month: 8, day: 1),
    datetime(year: 2026, month: 8, day: 31),
  ),
)

#line-items[
  #item(
    [Wartung],
    price: 300,
    tax: tax.vat(19%),
    date: (
      datetime(year: 2026, month: 8, day: 15),
      datetime(year: 2026, month: 9, day: 14),
    ),
  )
]
#payment-goal(days: 14)
#bank
