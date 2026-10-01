// expect: AGREE_INVALID FX-SCH-A-000429
// profiles: basic-wl
//
// A buyer electronic address (BT-49) with the scheme 0219, which the EAS code
// lists of EN 16931 have, but the one of Factur-X does not: only its
// Schematron rejects it (KoSIT accepts it, see validator-differences.toml).
// XRechnung accepts it (BR-CL-25--pass.typ).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: (scheme: "0219", id: "4711")),
  invoice-nr: "FX-SCH-A-000429--0219",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
