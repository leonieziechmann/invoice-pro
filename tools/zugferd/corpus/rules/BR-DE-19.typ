// expect: AGREE_INVALID BR-DE-19
// profiles: xrechnung
//
// An XRechnung paid by SEPA credit transfer to an IBAN (BT-84) with wrong
// check digits; KoSIT only warns.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-19",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank-details(bank: "Musterbank", iban: "DE89370400440532013001")
