// expect: AGREE_INVALID CII-SR-467
// finding: amounts-payment-means-api-gap
//
// Bank details next to a payment card: an invoice states one payment means
// (BT-81), so that the buyer does not pay twice. Mustang accepts two
// payment means; KoSIT rejects two different type codes (CII-SR-467 of the
// CEN Schematron 1.3.16, see tools/zugferd/validator-differences.toml),
// which invoice-pro reports.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-KARTE-UND-KONTO",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")
#bank
