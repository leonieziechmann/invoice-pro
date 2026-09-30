// expect: STRICTER IP-PAY-06
// finding: https://github.com/ConnectingEurope/eInvoicing-EN16931/issues/477
//
// An amount is due, but the invoice states neither a payment due date (BT-9)
// nor payment terms (BT-20). This was BR-CO-25 of EN 16931, which neither the
// CEN Schematron 1.3.16 nor Factur-X 1.09 checks in CII any more (Mustang
// 2.26.0 and KoSIT accept the invoice). invoice-pro keeps the check as its own
// rule IP-PAY-06 and reports the error.

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
