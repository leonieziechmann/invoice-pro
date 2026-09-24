// expect: AGREE_INVALID BR-CL-15
//
// A country of origin (BT-159) outside ISO 3166-1.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-15",
)

#line-items[
  #item([Ware], price: 100, quantity: 1, tax: tax.vat(19%), origin: "XX")
]
#payment-goal(days: 14)
#bank
