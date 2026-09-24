// expect: AGREE_INVALID CII-SR-470
// finding: amounts-payment-means-api-gap
//
// Paid by credit transfer, without the bank details: EN 16931 requires the
// account of a credit transfer (BT-84). The CII Schematron of CEN 1.3.12 in
// Mustang tests its BR-61 on the debited account
// (PayerPartyDebtorFinancialAccount) instead, so Mustang accepts the XML;
// KoSIT rejects it with CII-SR-470 of CEN 1.3.16, which invoice-pro reports.

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
