// expect: AGREE_INVALID FX-SCH-A-000023
// profiles: basic-wl
//
// A payment means code (BT-81) outside UNTDID 4461, in BASIC WL, whose
// validation applies the code list of Factur-X alone.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000023",
)

#line-items[
  #item-s
]
#paid(method: (code: "999", name: [Tausch]))
