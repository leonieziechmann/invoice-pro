// expect: AGREE_VALID
//
// The cash discount in the XRechnung syntax.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  due-date: "Zahlbar innerhalb von 30 Tagen.\n#SKONTO#TAGE=14#PROZENT=2.00#\n",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-18--pass",
)

#line-items[
  #item-s
]
#bank
