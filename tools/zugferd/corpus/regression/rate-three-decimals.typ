// expect: AGREE_VALID
// finding: tax-rate-rounded-to-2-decimals, core-rate-rounded-2dp
// facts: {"breakdown": [["S", "8.125"], ["S", "8.13"]]}
//
// VAT rates were written with two decimals: 8.125 % became 8.13 %, the two
// groups collapsed into one rate and BR-S-08 failed without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-RATE-3DEC",
)

#line-items[
  #item([A], price: 100.00, quantity: 1, tax: tax.vat(8.125%))
  #item([B], price: 100.00, quantity: 1, tax: tax.vat(8.13%))
]
#payment-goal(days: 14)
#bank
