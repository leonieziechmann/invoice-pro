// expect: AGREE_VALID
// profiles: xrechnung
//
// Gross prices: 1000 screws at 9.99 including 19 % VAT. The net price keeps
// enough decimals (8.394958) that the quantity times it is the line's net
// amount 8394.96 within 0.02; a net price of 4 decimals (8.3950) was 0.04
// off.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  tax-mode: "inclusive",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "PEPPOL-EN16931-R120--pass",
)

#line-items[
  #item([Schrauben], price: 9.99, quantity: 1000, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
