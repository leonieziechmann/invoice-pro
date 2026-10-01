// expect: AGREE_VALID
// finding: core-codelists-cen
//
// The scheme 0240 of the ISO/IEC 6523 ICD and EAS lists, which the lists of
// Factur-X 1.0.07 and CEN 1.3.12 in Mustang 2.14.0 lacked, so that
// invoice-pro reported BR-CL-10, BR-CL-11 and BR-CL-25. Every list of Mustang
// 2.26.0 and KoSIT has it now: the invoice stays valid.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr
    + (
      global-id: (scheme: "0240", id: "12345678"),
      legal-id: (scheme: "0240", id: "87654321"),
      electronic-address: (scheme: "0240", id: "12345678"),
    ),
  invoice-nr: "RG-SCHEME-0240",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
