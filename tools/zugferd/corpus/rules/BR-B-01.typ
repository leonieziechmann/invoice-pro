// expect: AGREE_INVALID BR-B-01
// profiles: basic en16931 xrechnung
//
// The split payment of Italy (B) on an invoice between German parties: the
// code lists of EN 16931, which the validation of XRechnung applies alone,
// have the category, but it is for domestic Italian invoices only. BASIC and
// EN 16931 reject the category as well (FX-SCH-A-000179, the code list of
// Factur-X).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-B-01",
)

#line-items[
  #item-with(tax.special.transferred(22%))
]
#payment-goal(days: 14)
#bank
