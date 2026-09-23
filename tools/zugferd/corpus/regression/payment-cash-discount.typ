// expect: AGREE_VALID
// finding: amounts-skonto-br-de-18-false-negative
// facts: {"payment_terms": "#SKONTO#TAGE=14#PROZENT=2.00#\n", "due_date": "20261001", "iban": "DE89370400440532013000"}
//
// A cash discount of 2 % within 14 days, net within 30 days: the invoice
// prints the discount, and XRechnung states it in the Skonto syntax of
// the KoSIT (BR-DE-18) from the same structure.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-SKONTO-STRUKTUR",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30, discount: (days: 14, percent: 2%))
#bank
