// expect: AGREE_VALID
// finding: amounts-payment-means-api-gap
// facts: {"payment_means": ["59"], "mandate": "M-2026-017", "creditor_id": "DE98ZZZ09999999999", "debtor_iban": "DE02120300000000202051", "due_date": "20260915"}
//
// An XRechnung collected by SEPA direct debit (BT-81 = 59): the mandate
// reference (BT-89), the creditor identifier (BT-90) and the debited
// account (BT-91). invoice-pro knew credit transfers only, so this invoice
// could not be produced.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-LASTSCHRIFT",
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
