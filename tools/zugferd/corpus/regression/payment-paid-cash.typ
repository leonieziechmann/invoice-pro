// expect: AGREE_VALID
// finding: amounts-payment-means-api-gap
// facts: {"payment_means": ["10"], "paid": true, "payment_terms": "Der Gesamtbetrag in Höhe von 1.190,00 € wurde am 01.09.2026 bezahlt.\nZahlungsart: Barzahlung"}
//
// An XRechnung paid in cash (BT-81 = 10): the paid amount (BT-113) is the
// total and nothing is due (BT-115). The payment terms (BT-20) state what
// the invoice prints about the payment.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-BAR",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
