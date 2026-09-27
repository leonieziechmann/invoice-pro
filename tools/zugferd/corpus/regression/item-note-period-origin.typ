// expect: AGREE_VALID
// finding: amounts-minor-reference-gaps
// facts: {"period": ["20260803", "20260814"]}
// facts: {"line_names": ["Montage", "Schulung", "Material"]}
//
// The note (BT-127), the date or period (BG-26) and the country of origin
// (BT-159) of the items: printed below the name of the item and written into
// the invoice lines. The invoicing period (BG-14) spans the dates of the
// items.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-ITEM-DATA",
)

#line-items[
  #item(
    [Montage],
    price: 480,
    tax: tax.vat(19%),
    date: datetime(year: 2026, month: 8, day: 3),
    note: "Einschließlich Anfahrt.\nAbnahme durch den Bauleiter.",
    origin: country.de,
  )
  #item(
    [Schulung],
    price: 900,
    tax: tax.vat(19%),
    date: (
      datetime(year: 2026, month: 8, day: 10),
      datetime(year: 2026, month: 8, day: 14),
    ),
    origin: "it",
  )
  #item([Material], price: 60, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
