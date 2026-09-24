// expect: AGREE_INVALID BR-CL-04
//
// A currency that is no ISO 4217 code: the validators report it for the
// invoice currency (BR-CL-04) and for the currency of the VAT total (BR-
// CL-03), which states the invoice currency; invoice-pro reports BR-CL-04.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  currency: "ABC",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-03",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
