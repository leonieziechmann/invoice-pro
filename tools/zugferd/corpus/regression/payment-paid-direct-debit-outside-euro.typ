// expect: AGREE_INVALID PEPPOL-EN16931-R061
// finding: amounts-payment-means-api-gap
//
// An XRechnung in Swiss francs paid by direct debit (BT-81 = 49), without the
// direct debit: XRechnung requires the mandate reference of any direct debit
// (PEPPOL-EN16931-R061), not only of a SEPA direct debit (BR-DE-25-a).
// invoice-pro attached it without a message.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  locale: locale.de-ch,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-LASTSCHRIFT-CHF",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#paid(method: "direct-debit")
