// expect: AGREE_INVALID BR-CL-04
// finding: core-codelists-cen
//
// The Bulgarian lev (BGN), which the ISO 4217 lists have withdrawn (Bulgaria
// pays in euro since 2026), in EN 16931: KoSIT rejects it (BR-CL-03,
// BR-CL-04), and so does Mustang 2.26.0 with the Factur-X 1.09 list
// (Mustang 2.14.0 accepted it, so invoice-pro only warned, IP-CODE-01).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  currency: "BGN",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-BGN",
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
