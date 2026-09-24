// expect: AGREE_INVALID BR-CL-04
// finding: core-codelists-cen
//
// The Bulgarian lev (BGN), which the code list of the EN 16931 Schematron
// 1.3.16 has withdrawn, in XRechnung: KoSIT rejects it (BR-CL-03, BR-CL-04),
// and so does invoice-pro, which allows the currency only where the Factur-X
// validation accepts it (currency-withdrawn-from-en16931-list.typ).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  currency: "BGN",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-CURRENCY-BGN-XR",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
