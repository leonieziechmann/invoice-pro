// expect: AGREE_INVALID CII-SR-470
// finding: amounts-payment-means-api-gap
//
// Paid by credit transfer, without the bank details: EN 16931 requires the
// account of a credit transfer (BT-84). Both validators reject it with
// CII-SR-470 (CEN 1.3.16 in KoSIT, Factur-X 1.09 in Mustang 2.26.0), which
// invoice-pro reports. Mustang 2.14.0, whose CEN 1.3.12 tested BR-61 on the
// debited account (PayerPartyDebtorFinancialAccount), accepted the XML.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-UEBERWEISUNG-OHNE-KONTO",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#paid(method: "transfer")
