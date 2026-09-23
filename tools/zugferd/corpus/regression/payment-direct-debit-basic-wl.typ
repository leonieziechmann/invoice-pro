// expect: AGREE_VALID
// finding: amounts-payment-means-api-gap
// facts: {"payment_means": ["59"], "mandate": "M-2026-017", "creditor_id": "DE98ZZZ09999999999", "debtor_iban": "DE02120300000000202051"}
//
// BASIC WL states the direct debit (BG-19) as well: the mandate reference,
// the creditor identifier and the debited account.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-LASTSCHRIFT-BWL",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
