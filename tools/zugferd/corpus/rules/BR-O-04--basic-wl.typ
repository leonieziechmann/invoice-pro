// expect: AGREE_INVALID BR-O-04
// profiles: basic-wl
//
// An invoice not subject to VAT (O) with a seller tax representative, whose
// VAT identifier (BT-63) it states, and a document level charge: BASIC WL
// states no lines, so its validation reports the charge (BR-O-04), and so
// does invoice-pro (BR-O-04.typ shows the other profiles).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de + (vat-id: none, tax-representative: representative),
  recipient: buyer-us,
  invoice-nr: "BR-O-04--basic-wl",
)

#line-items[
  #item-with(tax.outside-scope())
  #shipping
]
#payment-goal(days: 14)
#bank
