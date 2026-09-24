// expect: AGREE_INVALID BR-IC-11
// finding: merge-wave-3a-credit-note-k-undated
//
// A credit note for an intra-community supply (K) without dates: its own
// date is not the date of the supply, so the e-invoice states no delivery
// date (BT-72) and no invoicing period (BG-14), which BR-IC-11 requires for
// K. invoice-pro reports it instead of writing an invalid XML.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  document-type: "credit-note",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "GS-2026-7",
  preceding-invoice-nr: "R-2026-31",
)

#line-items[
  #item(
    [Maschinenteil],
    quantity: 2,
    price: 250,
    tax: tax.intra-community(
      grounds: "Steuerfreie innergemeinschaftliche Lieferung",
    ),
  )
]
#payment-goal(days: 14)
#bank-details(bank: "Banque Client", iban: "FR7630006000011234567890189")
