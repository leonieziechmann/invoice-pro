// expect: AGREE_VALID
// finding: review-wave-3c-net-price-13-decimals
// facts: {"tax_mode": "inclusive"}
//
// Gross prices with a quantity of billions: 2 000 000 000 calls at 0.0001
// including 19 % VAT. The net price needs 13 decimals (0.0000840336134) for
// the quantity times the price to be the line's net amount within 0.02
// (PEPPOL-EN16931-R120). The XML was written with at most 12, so it stated
// another price than the data model, which the round trip of the strict
// mode reported (IP-GUARD-10).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  tax-mode: "inclusive",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-HUGE-QUANTITY",
)

#line-items[
  #item([API-Aufrufe], price: 0.0001, quantity: 2000000000, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
