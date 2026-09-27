// expect: STRICTER IP-PAY-05
// finding: core-wrong-rule-ids
//
// A payee with the seller's name in BASIC WL: the Factur-X Schematron of the
// profile (FX-SCH-A-000075, BR-17) compares the payee with
// `../ram:SellerTradeParty`, which never matches from the settlement, so it
// requires the payee's name only and Mustang accepts the XML. invoice-pro
// reported BR-17, which no validator reports for it; it now reports its own
// rule (payee-is-seller.typ shows BR-17 in EN 16931).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  payee: (name: "Muster GmbH"),
  invoice-nr: "RG-PAYEE-SELLER-BWL",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
