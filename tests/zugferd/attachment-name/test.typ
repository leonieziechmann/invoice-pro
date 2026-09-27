// The name of the embedded e-invoice: "factur-x.xml", and "xrechnung.xml"
// in the XRECHNUNG profile (ZUGFeRD 2.3; Mustang embeds an XRechnung under
// that name as well). A draft with errors is "invoice-draft.xml" in any
// profile.

#import "/src/lib.typ": *
#import "/tests/zugferd/harness.typ": bank, buyer-de, buyer-fr, seller

#let e-invoice(..args) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
)[
  #line-items[#item([Beratung], price: 100, quantity: 2, unit: unit.hour)]
  #payment-goal(days: 14)
  #bank
]

// In this order: the attachments the documents below embed.
#e-invoice(zugferd: "xrechnung")
#e-invoice(zugferd: "en16931")
#e-invoice(zugferd: "basic-wl")
// `auto`: XRechnung for a buyer in Germany ...
#e-invoice(zugferd: auto)
// ... else EN 16931, e.g. without the buyer reference XRechnung requires
#e-invoice(zugferd: auto, recipient: buyer-de + (buyer-reference: none))
#e-invoice(zugferd: auto, recipient: buyer-fr)
// With errors: a draft in "report" mode, the e-invoice in "ignore" mode
#e-invoice(
  zugferd: "xrechnung",
  zugferd-errors: "report",
  recipient: buyer-de + (buyer-reference: none),
)
#e-invoice(
  zugferd: "xrechnung",
  zugferd-errors: "ignore",
  recipient: buyer-de + (buyer-reference: none),
)

#context {
  let attachments = query(pdf.attach).map(it => (it.path, it.relationship))
  assert.eq(attachments, (
    ("/xrechnung.xml", "alternative"),
    ("/factur-x.xml", "alternative"),
    ("/factur-x.xml", "data"),
    ("/xrechnung.xml", "alternative"),
    ("/factur-x.xml", "alternative"),
    ("/factur-x.xml", "alternative"),
    ("/invoice-draft.xml", "data"),
    ("/xrechnung.xml", "alternative"),
  ))
}
