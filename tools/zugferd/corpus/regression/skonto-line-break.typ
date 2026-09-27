// expect: AGREE_VALID
// finding: amounts-skonto-br-de-18-false-negative
//
// The XRechnung cash discount line (#SKONTO#...#) must end with a line break
// (BR-DE-18). The payment terms (BT-20) lost their line breaks, so this
// XRechnung was invalid without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-SKONTO",
  due-date: "#SKONTO#TAGE=10#PROZENT=2.00#\n",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#bank
