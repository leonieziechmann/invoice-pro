// expect: AGREE_VALID
// warns: PEPPOL-EN16931-R120
// profiles: xrechnung
//
// An XRechnung line whose net amount (BT-131) is not its quantity times its
// net price (BT-146): a price of 100.40 yen, which the line total rounds to
// whole yen (the yen has no decimals), 0.40 off. A warning in KoSIT, which
// invoice-pro reports as a warning too; Mustang does not check it.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  currency: "JPY",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "PEPPOL-EN16931-R120",
)

#line-items[
  #item([Leistung], price: 100.4, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
