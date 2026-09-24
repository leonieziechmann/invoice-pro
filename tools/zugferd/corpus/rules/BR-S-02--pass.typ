// expect: AGREE_VALID
// profiles: en16931
//
// A tax number (BT-32) identifies the seller for the VAT categories as well.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-fr,
  invoice-nr: "BR-S-02--pass",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
