// expect: AGREE_INVALID BR-DE-23-a
// profiles: xrechnung
//
// An XRechnung paid by credit transfer without the account (BG-17): KoSIT
// reports CII-SR-470 of the CEN Schematron 1.3.16 and BR-DE-23-a of the
// XRechnung Schematron, Mustang BR-DE-23-a; invoice-pro reports BR-DE-23-a.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "CII-SR-470--xrechnung",
)

#line-items[
  #item-s
]
#paid(method: "transfer")
