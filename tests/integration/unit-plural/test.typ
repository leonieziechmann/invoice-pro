// The unit column pluralises with each row's quantity, while the "unit for all
// items" note always names the unit in singular.
//
// Pages 1-3 are English, pages 4-6 German. Each page is one invoice:
//   1. Mixed quantities: unit column with 1, 2 and 2.5 per unit kind
//      (preset, (singular:, plural:) dictionary, plain string, bundle).
//   2. All items share quantity 2: the unit moves into the note, in singular.
//   3. Unit column hidden, quantities 1 and 2.5: the note is still shown,
//      because "hour" and "hours" are the same unit.

#import "/src/lib.typ": *

// Each invoice sets its own page (the frame owns `set page`): pages of auto
// height keep the references small. Several invoices in one document: bare
// fixtures, so validation is off.
#let scenario(loc, title, show-column: auto, body) = invoice(
  theme: theme.plain.with(
    theme.custom.page(paper: (width: 210mm, height: auto)),
  ),
  locale: loc,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
  date: datetime(year: 2026, month: 1, day: 15),
  validation: none,
)[
  #block(above: 2em, below: 0.8em, text(weight: "bold", title))
  #line-items(show-column: show-column, body)
]

#let page-for(loc, licence, plain) = {
  scenario(loc, [Mixed quantities])[
    #for q in (1, 2, 2.5) {
      item([Day], price: 10, quantity: q, unit: unit.day)
    }
    #for q in (1, 2, 2.5) {
      item([Licence], price: 10, quantity: q, unit: licence)
    }
    #for q in (1, 2, 2.5) {
      item([Plain string], price: 10, quantity: q, unit: plain)
    }
    #item([Default unit], price: 10, quantity: 2)
    #bundle([Bundle], quantity: 2.5, unit: unit.sets)[
      #item([Part], price: 10)
    ]
  ]

  scenario(loc, [Shared quantity 2])[
    #item([Workshop], price: 100, quantity: 2, unit: unit.day)
    #item([Support], price: 50, quantity: 2, unit: unit.day)
  ]

  scenario(
    loc,
    [Unit column hidden, quantities 1 and 2.5],
    show-column: (unit: false),
  )[
    #item([Consulting], price: 100, quantity: 1, unit: unit.hour)
    #item([Development], price: 80, quantity: 2.5, unit: unit.hour)
  ]
}

#page-for(locale.en-de, (singular: "licence", plural: "licences"), "hrs")

#page-for(locale.de-de, (singular: "Lizenz", plural: "Lizenzen"), "Std.")
