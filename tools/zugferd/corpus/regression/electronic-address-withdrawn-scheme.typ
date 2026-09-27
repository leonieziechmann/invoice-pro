// expect: AGREE_INVALID BR-CL-25
// finding: core-codelists-cen
//
// The EAS code list has withdrawn the scheme 9901: the EN 16931 Schematron
// 1.3.16 (KoSIT) rejects an electronic address with it (BR-CL-25), while
// Mustang, with the older lists, accepts it
// (tools/zugferd/validator-differences.toml). invoice-pro accepted it
// without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: (scheme: "9901", id: "12345678")),
  invoice-nr: "RG-EAS-9901",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
