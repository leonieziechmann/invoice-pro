// expect: AGREE_VALID
// finding: amounts-custom-locale-currency-eur
// facts: {"currency": "PLN"}
//
// The currency of a custom region is the invoice currency (BT-5): the XML
// must not say EUR while the PDF prints złoty.

#import "_base.typ": *
#import "/src/locale/lang/lang.typ" as lang

#let region-pl = lang => (
  meta: (region: "pl"),
  currency: (code: "PLN", symbol: "zł", decimals: 2, decimals-fine: 4),
  tax: (default-vat: tax.vat(23%)),
)

#show: invoice.with(
  ..setup,
  locale: locale.build-locale(lang.en, region-pl),
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-PLN",
)

#line-items[
  #item([Usługa], price: 1000, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
