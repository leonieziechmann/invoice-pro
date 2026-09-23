// expect: AGREE_VALID
// finding: robustness-unit-strings-mapped-to-c62, amounts-unit-string-mapping
// facts: {"units": ["MTK", "KMT", "TNE", "HUR"]}
//
// Common unit symbols have a UN/ECE Recommendation 20 code (BT-130); they
// were written as C62 ("one"), which misstates the quantity.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-UNITS",
)

#line-items[
  #item([Fläche], price: 10, quantity: 2, unit: "m²", tax: tax.vat(19%))
  #item([Strecke], price: 10, quantity: 2, unit: "km", tax: tax.vat(19%))
  #item([Gewicht], price: 10, quantity: 2, unit: "t", tax: tax.vat(19%))
  #item([Arbeit], price: 10, quantity: 2, unit: unit.hour, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
