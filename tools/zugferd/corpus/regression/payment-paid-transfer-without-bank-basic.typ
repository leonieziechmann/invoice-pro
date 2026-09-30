// expect: AGREE_INVALID CII-SR-470
// finding: core-wrong-rule-ids
//
// Paid by credit transfer, without the bank details, in BASIC: CII-SR-470 of
// the CEN Schematron 1.3.16 and of Factur-X 1.09 in Mustang rejects it (KoSIT
// has no scenario for BASIC). Until Mustang 2.14.0, whose BR-61 tests the
// debited account, invoice-pro reported its own IP-PAY-04.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-UEBERWEISUNG-OHNE-KONTO-BASIC",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#paid(method: "transfer")
