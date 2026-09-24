// expect: AGREE_VALID
// warns: BR-DE-TMP-32
//
// A credit note in XRechnung without dates states no date of the supply
// (BT-72, BG-14): information in KoSIT, a warning of invoice-pro.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "credit-note",
  preceding-invoice-nr: "R-2026-11",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-TMP-32",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank-details(bank: "Kundenbank", iban: "DE75512108001245126199")
