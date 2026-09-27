// expect: AGREE_INVALID BR-CL-04
// finding: core-codelists-cen
//
// The Caribbean guilder (XCG, since 2025) is in the code list of the EN 16931
// Schematron 1.3.16 (KoSIT), but not in the lists of Factur-X 1.0.07 and of
// the older EN 16931 Schematron in Mustang, which rejects the invoice
// (tools/zugferd/validator-differences.toml). invoice-pro follows Mustang
// and reports an error.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  currency: "XCG",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-XCG",
)

#line-items[
  #item(
    [Pumpen],
    price: 100,
    quantity: 10,
    tax: tax.export(
      grounds: "Steuerfreie Ausfuhrlieferung nach § 4 Nr. 1 Buchst. a UStG",
    ),
  )
]
#payment-goal(days: 14)
#bank
