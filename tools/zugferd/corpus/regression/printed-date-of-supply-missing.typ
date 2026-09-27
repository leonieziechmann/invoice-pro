// expect: STRICTER IP-PERIOD-03
// finding: legal-date-of-supply-not-printed
//
// References of their own without the date of the supply, and no dates on
// the items: the XML states the invoice date as the date of the supply
// (BT-72), which is valid, but the printed invoice of a seller in Germany
// must show it as well (§ 14 Abs. 4 Satz 1 Nr. 6 UStG), not only as the
// invoice date.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  theme: harness(themes.DIN-5008(font: "libertinus serif")),
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PRINTED-SUPPLY",
  references: (
    references.invoice-nr(),
    references.invoice-date(),
    references.seller-vat-id(),
  ),
)

#line-items[
  #item([Wartung], quantity: 4, unit: unit.hour, price: 95)
]
#payment-goal(days: 14)
#bank
