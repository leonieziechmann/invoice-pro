// expect: AGREE_INVALID BR-IC-11
//
// A credit note for an intra-community supply (K) without dates: its own date
// is not the date of the supply (BT-72, BG-14).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  document-type: "credit-note",
  preceding-invoice-nr: "R-2026-31",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-IC-11",
)

#line-items[
  #item-with(tax.intra-community())
]
#payment-goal(days: 14)
#bank-details(bank: "Banque Client", iban: "FR7630006000011234567890189")
