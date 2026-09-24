// expect: AGREE_INVALID PEPPOL-EN16931-R061
//
// An XRechnung in Swiss francs paid by direct debit (BT-81 = 49) without the
// mandate reference (BT-89).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  locale: locale.de-ch,
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "PEPPOL-EN16931-R061",
)

#line-items[
  #item-s
]
#paid(method: "direct-debit")
