// expect: STRICTER IP-PAY-04
// finding: core-wrong-rule-ids
//
// Paid by credit transfer, without the bank details, in BASIC: the validation
// of the profile accepts it (its BR-61 tests the debited account, and KoSIT
// has no scenario for BASIC), but the buyer would not know where the amount
// went. invoice-pro reports its own rule instead of BR-61, which no validator
// reports for this XML.

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
