// expect: AGREE_VALID
// finding: legal-seller-tax-id-not-printed, legal-date-of-supply-not-printed
//
// The DIN 5008 letter prints the reference signs, so the e-invoice checks
// that the printed invoice shows the seller's tax number or VAT ID and the
// date of the supply (IP-PRINT-03, IP-PERIOD-03). The default references
// print both: a legal invoice without findings.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  theme: harness(theme.classic.with(
    theme.custom.fonts(body: "libertinus serif"),
    // the DIN 5008 letter of 0.4 had no legal footer, which would print the
    // seller's VAT ID and tax number
    theme.custom.area("footer", none),
  )),
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PRINTED-DEFAULTS",
)

#line-items[
  #item([Wartung], quantity: 4, unit: unit.hour, price: 95)
]
#payment-terms(days: 14)
#bank
