// expect: AGREE_VALID
// finding: legal-seller-tax-id-not-printed, legal-date-of-supply-not-printed
//
// The DIN 5008 letter says what it prints, so the e-invoice checks that the
// printed invoice shows the seller's tax number or VAT ID and the date of the
// supply (IP-PRINT-03, IP-PERIOD-03). The default references print both: a
// legal invoice without findings.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  theme: harness(themes.DIN-5008(font: "libertinus serif")),
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PRINTED-DEFAULTS",
)

#line-items[
  #item([Wartung], quantity: 4, unit: unit.hour, price: 95)
]
#payment-goal(days: 14)
#bank
