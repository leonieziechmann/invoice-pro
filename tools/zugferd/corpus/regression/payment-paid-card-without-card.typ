// expect: AGREE_INVALID BR-DE-24-a
// finding: amounts-payment-means-api-gap
//
// Paid by card, without the card: XRechnung requires the payment card
// (BG-18) of a card payment.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-KARTE-OHNE-KARTE",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#paid(method: "card")
