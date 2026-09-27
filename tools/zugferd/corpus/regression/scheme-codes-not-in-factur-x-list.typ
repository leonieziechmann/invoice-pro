// expect: AGREE_INVALID BR-CL-10 BR-CL-11 BR-CL-25
// finding: core-codelists-cen
//
// The scheme 0240 is in the ISO/IEC 6523 ICD and EAS lists of the EN 16931
// Schematron 1.3.16 (KoSIT), but not in the lists of Factur-X 1.0.07 and of
// the older EN 16931 Schematron in Mustang, which rejects it as the scheme of
// a party identifier (BR-CL-10), a legal registration identifier (BR-CL-11)
// and an electronic address (BR-CL-25)
// (tools/zugferd/validator-differences.toml). invoice-pro follows Mustang
// and reports an error for each.

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
