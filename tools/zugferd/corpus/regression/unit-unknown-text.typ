// expect: REJECTED
// finding: robustness-unit-strings-mapped-to-c62
//
// A free-text unit without a UN/ECE Recommendation 20 code was silently
// written as C62 ("one"). In e-invoice mode it is an error with a hint to
// `unit.*` or a Rec 20 code (maintainer decision).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-UNIT-TEXT",
)

#line-items[
  #item(
    [Umzugskartons],
    price: 10,
    quantity: 2,
    unit: "Kartons",
    tax: tax.vat(19%),
  )
]
#payment-goal(days: 14)
#bank
