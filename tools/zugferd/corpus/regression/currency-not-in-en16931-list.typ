// expect: AGREE_VALID
// finding: core-codelists-cen
//
// The current bolívar (VES), which the EN 16931 code list of Mustang 2.14.0
// (CEN 1.3.12) lacked, so that invoice-pro reported BR-CL-04. Every list of
// Mustang 2.26.0 and KoSIT has it now: the invoice stays valid.

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
