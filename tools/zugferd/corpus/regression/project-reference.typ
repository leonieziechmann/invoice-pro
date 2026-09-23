// expect: AGREE_VALID
// finding: robustness-printed-refs-missing-in-xml
//
// The project the invoice prints (`references.project()`) is written as the
// project reference (BT-11), which public buyers often require.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PROJECT",
  project: "Projekt Apollo",
  references: (references.invoice-nr(), references.project()),
)

#line-items[
  #item([Beratung], quantity: 8, unit: unit.hour, price: 120, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
