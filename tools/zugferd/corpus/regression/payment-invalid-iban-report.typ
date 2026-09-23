// expect: AGREE_INVALID BR-DE-19
// finding: robustness-invalid-iban-epc-panic
//
// With `zugferd-errors: "report"`, an invalid IBAN was only a warning, so
// the XRechnung was attached as `factur-x.xml`, although the validators
// reject it (BR-DE-19). It is an error now, and the XML only a draft.

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
