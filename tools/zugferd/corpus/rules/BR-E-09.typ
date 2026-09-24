// expect: AGREE_INVALID BR-E-09
// profiles: basic-wl
//
// Exempt items (E) with a rate other than 0 %, which the category does not
// allow: in BASIC WL, without lines, its VAT breakdown states a VAT amount
// (BT-117) other than 0.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-E-09",
)

#line-items[
  #item-with(tax.new(
    rate: 7%,
    category: "E",
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
  ))
]
#payment-goal(days: 14)
#bank
