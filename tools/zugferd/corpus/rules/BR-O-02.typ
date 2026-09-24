// expect: AGREE_INVALID BR-O-02
//
// An invoice not subject to VAT (O) that names a seller tax representative
// (BG-11), whose VAT identifier it would state.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (vat-id: none, tax-representative: representative),
  recipient: buyer-us,
  invoice-nr: "BR-O-02",
)

#line-items[
  #item-with(tax.outside-scope())
]
#payment-goal(days: 14)
#bank
