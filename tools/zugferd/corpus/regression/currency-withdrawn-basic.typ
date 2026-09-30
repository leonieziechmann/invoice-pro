// expect: AGREE_INVALID FX-SCH-A-000514
// finding: core-wrong-rule-ids
//
// The Bulgarian lev (BGN), which the ISO 4217 lists have withdrawn (Bulgaria
// pays in euro since 2026), in BASIC. Mustang 2.14.0 still accepted it (the
// Factur-X list and CEN 1.3.12), so invoice-pro only warned (IP-CODE-01);
// the Factur-X 1.09 list of Mustang 2.26.0 has withdrawn it as well, which
// BASIC applies alone: an error under the rule of the Factur-X Schematron of
// the position.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic",
  currency: "BGN",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-BGN-BASIC",
)

#line-items[
  #item(
    [Pumpen],
    price: 100,
    quantity: 10,
    tax: tax.export(
      grounds: "Steuerfreie Ausfuhrlieferung nach § 4 Nr. 1 Buchst. a UStG",
    ),
  )
]
#payment-goal(days: 14)
#bank
