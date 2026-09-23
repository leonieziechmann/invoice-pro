// expect: AGREE_VALID
// finding: core-eaddr-empty-uri, robustness-empty-electronic-address-empty-element
//
// An empty `electronic-address` is not set: the buyer's electronic address
// comes from the VAT identifier as usual. It was written as an empty
// URIUniversalCommunication (XSD, BR-62/BR-63) without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: ""),
  invoice-nr: "RG-EADDR-EMPTY",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
