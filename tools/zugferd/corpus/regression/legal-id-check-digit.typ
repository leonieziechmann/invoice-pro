// expect: STRICTER IP-ID-01
// finding: parties-bt30-bt47-legal-registration-missing
//
// A SIRET with a wrong check digit, most likely a typo, is valid for the
// official validators, which check no check digits. invoice-pro reports it
// (IP-ID-01, a maintainer decision); `id.custom("0009", ..)` would take the
// identifier as it is.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (legal-id: id.siret("123 456 782 00011")),
  recipient: buyer-fr,
  invoice-nr: "RG-SIRET-CHECK",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
