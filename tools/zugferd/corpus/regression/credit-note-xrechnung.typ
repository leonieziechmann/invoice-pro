// expect: AGREE_VALID
// finding: amounts-doctype-gutschrift-written-as-380
// facts: {"type_code": "381", "seller_name": "Muster GmbH", "buyer_name": "Kunde AG", "iban": "DE75512108001245126199"}
//
// A credit note between German parties in XRechnung: document type 381 with
// positive amounts, the amount refunded to the buyer's account (BG-16, which
// XRechnung requires on credit notes as well, BR-DE-1) and a refund date.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "credit-note",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RK-2026-17",
  preceding-invoice-nr: "R-2026-11",
)

#line-items[
  #item([Bonus 2026], price: 500, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank-details(bank: "Kundenbank", iban: "DE75512108001245126199")
