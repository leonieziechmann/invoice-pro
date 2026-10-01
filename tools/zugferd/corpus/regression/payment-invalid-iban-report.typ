// expect: STRICTER IP-PAY-01
// finding: robustness-invalid-iban-epc-panic
//
// With `zugferd-errors: "report"`, an invalid IBAN was only a warning, so
// the XRechnung was attached as `factur-x.xml`. It is an error now
// (IP-PAY-01), and the XML only a draft: the amount could not be paid. The
// validators only warn (BR-DE-19, a warning since Mustang 2.26.0).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-IBAN",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank-details(iban: "DE00370400440532013000", qr-code: (display: false))
