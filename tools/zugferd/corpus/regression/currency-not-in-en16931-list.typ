// expect: AGREE_INVALID BR-CL-04
// finding: core-codelists-cen
//
// The EN 16931 code list lacks the current bolívar (VES), which the Factur-X
// list has. Mustang applies both lists, so an EN 16931 invoice in VES cannot
// validate; invoice-pro accepted it without a report.

#import "_base.typ": *
#import "/src/locale/lang/lang.typ" as lang

#let region-ve = lang => (
  meta: (region: "ve"),
  currency: (code: "VES", symbol: "Bs.", decimals: 2, decimals-fine: 4),
  tax: (default-vat: tax.vat(16%)),
)

#show: invoice.with(
  ..setup,
  locale: locale.build-locale(lang.es, region-ve),
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-VES",
)

#line-items[
  #item(
    [Bombas],
    price: 100,
    quantity: 10,
    tax: tax.export(grounds: "Exportación"),
  )
]
#payment-goal(days: 14)
#bank
