// expect: AGREE_INVALID BR-17
// finding: parties-payee-bt85-missing
//
// The payee (BG-10) is stated when someone other than the seller receives
// the payment. A payee with the seller's name contradicts that (BR-17).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  payee: (name: "Muster GmbH"),
  invoice-nr: "RG-PAYEE-SELLER",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
