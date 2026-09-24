// expect: AGREE_INVALID BR-CO-18
// profiles: basic-wl
//
// A BASIC WL invoice without items has no VAT breakdown (BG-23).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CO-18",
)

#line-items[]
#payment-goal(days: 14)
#bank
