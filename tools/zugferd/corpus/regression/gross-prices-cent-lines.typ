// expect: AGREE_VALID
// finding: review-wave-3c-net-amounts-cent-lines
// facts: {"tax_mode": "inclusive"}
//
// Gross prices: one line of 100.00 and 30 lines of 0.01 including 19 % VAT.
// Each cent line is 0.0084 net and rounds up to 0.01, so the rounded net
// amounts exceed the printed taxable amount 84.29 by 4 cents. They go to
// four of the cent lines, which state 0.00; before, all four went to the
// one line above a cent (83.99 instead of 84.03), and IP-PRINT-01 stopped a
// legal invoice.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  tax-mode: "inclusive",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-CENT-LINES",
)

#line-items[
  #item([Gerät], price: 100, quantity: 1, tax: tax.vat(19%))
  #for i in range(30) {
    item([Kleinteil #(i + 1)], price: 0.01, quantity: 1, tax: tax.vat(19%))
  }
]
#payment-goal(days: 14)
#bank
