// expect: AGREE_INVALID BR-G-03
// profiles: basic-wl
//
// An export outside the EU (G) on a document level allowance without the
// seller VAT identifier (BT-31); its tax number does not do. BASIC WL has no
// lines, so the rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-us,
  invoice-nr: "BR-G-03",
)

#line-items[
  #item-with(tax.export())
  #rebate
]
#payment-goal(days: 14)
#bank
