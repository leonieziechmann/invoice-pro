// expect: AGREE_INVALID BR-CO-25
//
// An amount due without payment due date (BT-9) or payment terms (BT-20);
// KoSIT's CEN Schematron 1.3.16 no longer checks it.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CO-25",
)

#line-items[
  #item-s
]
#bank
