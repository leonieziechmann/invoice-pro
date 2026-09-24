// expect: AGREE_INVALID BR-CO-25
// finding: https://github.com/ConnectingEurope/eInvoicing-EN16931/issues/477
//
// An amount is due, but the invoice states neither a payment due date (BT-9)
// nor payment terms (BT-20). The Factur-X Schematron in Mustang rejects it
// (BR-CO-25); the CEN Schematron 1.3.16 in KoSIT no longer checks BR-CO-25
// in CII (tools/zugferd/validator-differences.toml). invoice-pro follows
// Factur-X and reports the error.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-OHNE-ZAHLUNGSZIEL",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#bank
