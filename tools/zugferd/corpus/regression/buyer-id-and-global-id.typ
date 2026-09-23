// expect: AGREE_INVALID CII-SR-450
// finding: robustness-buyer-id-and-globalid-cii-sr-450
//
// The buyer identifier (BT-46) can be given once: either `id` or
// `global-id`. Both were written (ram:ID and ram:GlobalID) without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr
    + (id: "CUST-99", global-id: (scheme: "0088", id: "4000001987658")),
  invoice-nr: "RG-BUYER-IDS",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
