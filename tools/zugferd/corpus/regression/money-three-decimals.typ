// expect: REJECTED
// finding: amounts-rounding-false-negative-custom-money
//
// A locale that rounds money to three decimals: the line amounts (two
// decimals in the XML) no longer add up to the totals (BR-CO-10, BR-S-08),
// and nothing was reported. invoice-pro must stop, whichever rule it names
// (the decimals, BR-DEC-*, or its own IP-DEC-01).

#import "_base.typ": *

#let round-three = x => calc.round(x, digits: 3)

#show: invoice.with(
  ..setup,
  locale: locale.de-de.with(locale.custom.normalize(money: round-three)),
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-MONEY-3DEC",
)

#line-items[
  #item([A], price: 3.3333, quantity: 1, tax: tax.vat(19%))
  #item([B], price: 3.3333, quantity: 1, tax: tax.vat(19%))
  #item([C], price: 3.3333, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
