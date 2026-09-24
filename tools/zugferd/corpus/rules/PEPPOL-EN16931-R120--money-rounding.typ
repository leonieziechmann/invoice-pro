// expect: AGREE_VALID
// warns: PEPPOL-EN16931-R120
// profiles: xrechnung
//
// Net prices in euro with a `money` rounding of the locale to 0.05: the line
// total of 1 x 0.325 is 0.35, 0.025 more than the quantity times the price,
// beyond the 0.02 the rule allows. A warning in KoSIT, which invoice-pro
// reports as a warning too; before, it checked the rule only on lines whose
// total the currency rounds (e.g. yen) or that it had to look at anyway.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  locale: locale.de-de.with(locale.custom.normalize(
    money: x => calc.round(x * 20) / 20,
  )),
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "PEPPOL-EN16931-R120--money-rounding",
)

#line-items[
  #item([Kabel], price: decimal("0.325"), quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
