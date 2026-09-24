// expect: AGREE_INVALID BR-O-02
// profiles: basic en16931 xrechnung
//
// An invoice not subject to VAT (O) with a seller tax representative, whose
// VAT identifier (BT-63) it states, and a document level charge: the
// validators report the line (BR-O-02) and the charge (BR-O-04); invoice-pro
// reports BR-O-02.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none, tax-representative: representative),
  recipient: buyer-us,
  invoice-nr: "BR-O-04",
)

#line-items[
  #item-with(tax.outside-scope())
  #shipping
]
#payment-goal(days: 14)
#bank
