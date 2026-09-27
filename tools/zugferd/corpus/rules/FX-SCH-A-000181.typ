// expect: AGREE_INVALID FX-SCH-A-000181
// profiles: basic-wl
//
// A VAT exemption reason code (BT-121) outside the VATEX list, in BASIC WL,
// whose validation applies the code list of Factur-X alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000181",
)

#line-items[
  #item-with(tax.exempt(
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
    code: "VATEX-EU-XXX",
  ))
]
#payment-goal(days: 14)
#bank
