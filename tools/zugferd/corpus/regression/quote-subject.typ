// expect: STRICTER IP-DOC-01
// finding: amounts-doctype-gutschrift-written-as-380
//
// A quote ("Angebot") is no invoice, but with `zugferd` set it was written as
// a commercial invoice (BT-3 = 380). Its subject stops the e-invoice.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "ANG-2026-5",
  subject: "Angebot",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, unit: unit.hour)
]
#payment-goal(days: 14)
#bank
