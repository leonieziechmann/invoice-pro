// expect: AGREE_INVALID CII-SR-467
// finding: core-wrong-rule-ids
//
// Bank details next to a payment card in BASIC: two payment means, which
// CII-SR-467 of the CEN Schematron 1.3.16 and of Factur-X 1.09 in Mustang
// rejects (KoSIT has no scenario for BASIC). Until Mustang 2.14.0, whose CEN
// Schematron 1.3.12 lacked the rule, invoice-pro reported its own IP-PAY-03.

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
