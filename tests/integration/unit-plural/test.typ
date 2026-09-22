// The unit column pluralises with each row's quantity, while the "unit for all
// items" note always names the unit in singular.
//
// Page 1 is English, page 2 German. Each page renders three invoices:
//   1. Mixed quantities: unit column with 1, 2 and 2.5 per unit kind
//      (preset, (singular:, plural:) dictionary, plain string, bundle).
//   2. All items share quantity 2: the unit moves into the note, in singular.
//   3. Unit column hidden, quantities 1 and 2.5: the note is still shown,
//      because "hour" and "hours" are the same unit.

#import "/src/lib.typ": *

#set page(height: auto)

#let scenario(loc, title, show-column: auto, body) = {
  block(above: 2em, below: 0.8em, text(weight: "bold", title))
  invoice(
    theme: themes.blank,
    locale: loc,
    sender: (name: "Test Sender", address: "Street 1", city: "City"),
    recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
    line-items(show-column: show-column, body),
  )
}

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

#pagebreak()

#page-for(locale.de-de, (singular: "Lizenz", plural: "Lizenzen"), "Std.")
