// expect: AGREE_INVALID FX-SCH-A-000026
// profiles: en16931
//
// An item from the Netherlands Antilles (AN), which the code lists of
// EN 16931 still have, but the one of Factur-X does not: only its Schematron
// rejects the country of origin (BT-159) (KoSIT accepts it, see
// validator-differences.toml).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "FX-SCH-A-000026",
)

#line-items[
  #item([Ware], price: 100, quantity: 1, tax: tax.vat(19%), origin: "AN")
]
#payment-goal(days: 14)
#bank
