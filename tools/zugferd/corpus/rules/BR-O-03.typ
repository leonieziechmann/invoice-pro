// expect: AGREE_INVALID BR-O-02
//
// An invoice not subject to VAT (O) with a seller tax representative, whose
// VAT identifier (BT-63) it states, and a document level allowance: the
// validators report the line (BR-O-02) and the allowance (BR-O-03); invoice-
// pro reports BR-O-02.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (vat-id: none, tax-representative: representative),
  recipient: buyer-us,
  invoice-nr: "BR-O-03",
)

#line-items[
  #item-with(tax.outside-scope())
  #rebate
]
#payment-goal(days: 14)
#bank
