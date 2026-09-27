// expect: AGREE_INVALID BR-05
// profiles: minimum basic-wl basic en16931 xrechnung
//
// An invoice without a currency (BT-5): a locale without a currency code, and
// no `currency`.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  locale: locale.de-de.with((region: (currency: (code: "")))),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-05",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
