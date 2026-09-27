// expect: AGREE_INVALID BR-CL-22
// profiles: basic en16931 xrechnung
//
// A VAT exemption reason code (BT-121) outside the VATEX list.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-22",
)

#line-items[
  #item-with(tax.exempt(
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
    code: "VATEX-EU-XXX",
  ))
]
#payment-goal(days: 14)
#bank
