// expect: AGREE_INVALID BR-S-03
//
// Standard rated items (S) on a document level allowance without the seller
// VAT identifier (BT-31) or tax number (BT-32). BASIC WL has no lines, so the
// rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-S-03",
)

#line-items[
  #item-with(tax.vat(19%))
  #rebate
]
#payment-goal(days: 14)
#bank
