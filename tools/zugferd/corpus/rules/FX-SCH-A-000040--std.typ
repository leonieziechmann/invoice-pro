// expect: AGREE_INVALID FX-SCH-A-000040
// profiles: basic en16931
//
// The São Tomé dobra of before 2018 (STD), which the code lists of EN 16931
// still have, but the one of Factur-X does not: only its Schematron rejects
// it (KoSIT accepts it, see validator-differences.toml).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  currency: "STD",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000040--std",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
