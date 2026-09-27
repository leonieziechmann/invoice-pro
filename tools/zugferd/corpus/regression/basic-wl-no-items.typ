// expect: AGREE_INVALID BR-CO-18
// finding: core-basicwl-no-items
//
// Without items, a BASIC WL invoice has no VAT breakdown (BR-CO-18, and the
// XSD requires one). It was written without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-BASIC-WL-EMPTY",
  tax: tax.reverse-charge(),
)

#line-items[]
#payment-goal(days: 14)
#bank
