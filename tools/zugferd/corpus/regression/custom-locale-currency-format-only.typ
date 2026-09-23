// expect: STRICTER IP-PRINT-02
// finding: amounts-custom-locale-currency-eur
//
// A custom region (as the documentation showed it) prints amounts in złoty
// but states no currency code, so the XML said EUR (BT-5) without a report.
// An e-invoice must not state another currency than the one printed:
// invoice-pro stops with its own rule and asks for the code.

#import "_base.typ": *
#import "/src/locale/lang/lang.typ" as lang

#let region-pl = lang => (
  meta: (region: "pl"),
  format: (
    currency: val => {
      let rounded = calc.round(val, digits: 2)
      str(rounded).replace(".", ",") + " zł"
    },
  ),
  tax: (default-vat: tax.vat(23%)),
)

#show: invoice.with(
  ..setup,
  locale: locale.build-locale(lang.en, region-pl),
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-PLN-FORMAT",
)

#line-items[
  #item([Usługa], price: 1000, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
