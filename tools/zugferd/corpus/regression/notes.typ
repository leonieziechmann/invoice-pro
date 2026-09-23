// expect: AGREE_VALID
// finding: amounts-minor-reference-gaps
//
// The notes of the invoice are printed below the line items and written as
// invoice notes (BT-22) with their line breaks, one with the subject code
// "AAI" (BT-21).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-NOTES",
  notes: (
    "Lieferung frei Haus.\nMontage nach Absprache.",
    (
      text: "Es gelten unsere Allgemeinen Geschäftsbedingungen.",
      subject-code: "AAI",
    ),
  ),
)

#line-items[
  #item([Wartung August], price: 480, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
