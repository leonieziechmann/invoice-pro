// expect: STRICTER IP-DOC-01
// finding: amounts-doctype-gutschrift-written-as-380
//
// The subject says "Gutschrift" (credit note), but the XML was a commercial
// invoice (BT-3 = 380) that asks the buyer to pay. Without a document type,
// such a subject is an error in e-invoice mode (maintainer decision).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-GUTSCHRIFT",
  subject: "Gutschrift",
  preceding-invoice-nr: "R-2026-17",
  due-date: "Der Betrag wird Ihrem Konto gutgeschrieben.",
)

#line-items[
  #item([Bonus 2026], price: 500, quantity: 1, tax: tax.vat(19%))
]
#bank
