// expect: AGREE_INVALID BR-CL-04
// finding: core-codelists-cen
//
// The code list of the EN 16931 Schematron 1.3.16 (KoSIT) has withdrawn the
// Bulgarian lev (BGN): Bulgaria pays in euro since 2026. KoSIT rejects an
// EN 16931 invoice in BGN (BR-CL-03, BR-CL-04), while Mustang, with the
// older list, accepts it (tools/zugferd/validator-differences.toml).
// invoice-pro accepted it without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  currency: "BGN",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-BGN",
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
