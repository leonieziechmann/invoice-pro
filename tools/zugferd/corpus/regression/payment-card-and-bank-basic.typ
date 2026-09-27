// expect: STRICTER IP-PAY-03
// finding: core-wrong-rule-ids
//
// Bank details next to a payment card in BASIC: the validation of the
// profile accepts two payment means (CII-SR-467 is a rule of the CEN
// Schematron 1.3.16 only, and KoSIT has no scenario for BASIC), but the
// buyer would not know how to pay. invoice-pro reports its own rule.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-KARTE-UND-KONTO-BASIC",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")
#bank
