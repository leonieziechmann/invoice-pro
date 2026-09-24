// expect: AGREE_INVALID BR-DE-18
// profiles: xrechnung
//
// An XRechnung whose payment terms (BT-20) have a cash discount line that does
// not follow the XRechnung syntax (the percent needs two decimals).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  due-date: "Zahlbar innerhalb von 30 Tagen.\n#SKONTO#TAGE=14#PROZENT=2#\n",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-18",
)

#line-items[
  #item-s
]
#bank
