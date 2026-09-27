// expect: STRICTER IP-PRINT-03
// finding: legal-seller-tax-id-not-printed
//
// References of their own without the seller's tax number and VAT ID: the
// XML states both (BT-31, BT-32), which is valid, but the printed invoice
// shows neither, although the law requires one of them on the invoice
// (§ 14 Abs. 4 Satz 1 Nr. 2 UStG).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  theme: harness(themes.DIN-5008(font: "libertinus serif")),
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PRINTED-TAX-ID",
  references: (references.invoice-nr(), references.service-time()),
)

#line-items[
  #item([Wartung], quantity: 4, unit: unit.hour, price: 95)
]
#payment-goal(days: 14)
#bank
