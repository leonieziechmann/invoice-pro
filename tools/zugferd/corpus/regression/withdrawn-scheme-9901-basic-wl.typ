// expect: STRICTER IP-CODE-01
// finding: core-wrong-rule-ids
//
// A buyer electronic address (BT-49) with the scheme 9901, which the EAS code
// list of the EN 16931 Schematron 1.3.16 has withdrawn. BASIC WL is validated
// with the Factur-X list alone, which still has it, so Mustang accepts the
// XML; a receiver that applies the current list rejects it. invoice-pro
// reported BR-CL-25, which no validator of BASIC WL has; it now reports its
// own rule (the scheme stops EN 16931 and XRechnung as BR-CL-25, which KoSIT
// reports).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: (scheme: "9901", id: "12345678")),
  invoice-nr: "RG-SCHEME-9901-BWL",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
