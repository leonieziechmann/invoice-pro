// The items of the column-order tests: an item with a description, one with a
// relative discount, one with an absolute discount and a surcharge, a group
// with a discounted item and its subtotal, and a bundle with a discount, in
// two VAT rates, so that every value column shows.
#import "/tests/theme/body.typ": *

#let column-order-items(show-column: auto) = line-items(
  show-column: show-column,
)[
  #item(
    [Konzeption],
    price: 1800,
    tax: 19%,
    description: [Workshops und Entwürfe],
  )
  #item([Druck], price: 95, quantity: 4, tax: 7%, modifier: discount(
    [Paket],
    amount: 10%,
  ))
  #item([Express], price: 50, tax: 19%, modifier: (
    discount([Treue], amount: 5),
    surcharge([Eilzuschlag], amount: 15),
  ))
  #group([Phase 2])[
    #item([Reinzeichnung], price: 650, tax: 19%)
    #item([Satz], price: 120, quantity: 3, tax: 19%, modifier: discount(
      [Menge],
      amount: 5%,
    ))
  ]
  #bundle([Mappe], tax: 19%)[
    #item([Umschlag], price: 10)
    #item([Karte], price: 20, quantity: 2)
    #discount([Bündelrabatt], amount: 10%)
  ]
]

/// The theme of the column-order tests: `preset` with the value columns in
/// `order` (`items-table(column-order:)`).
#let column-order-theme(order, preset: theme.classic) = preset.with(
  theme.custom.items-table(column-order: order),
  layout: theme.layout.din-5008-a,
)
