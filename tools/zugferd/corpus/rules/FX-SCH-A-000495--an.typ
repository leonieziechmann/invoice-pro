// expect: AGREE_INVALID FX-SCH-A-000495
// profiles: basic
//
// A buyer in the Netherlands Antilles (AN), which the code lists of EN 16931
// still have, but the one of Factur-X does not: only its Schematron rejects
// the buyer country code (BT-55) (KoSIT accepts it, see
// validator-differences.toml).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic"),
  sender: seller-de,
  recipient: buyer-us + (country: "AN"),
  invoice-nr: "FX-SCH-A-000495--an",
)

#line-items[
  #item-with(
    tax.export(
      grounds: "Steuerfreie Ausfuhrlieferung nach § 4 Nr. 1 Buchst. a UStG",
    ),
  )
]
#payment-goal(days: 14)
#bank
