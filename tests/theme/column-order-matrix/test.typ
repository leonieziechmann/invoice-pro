/// [ppi: 12]

// items-table(column-order:) in every position of the total price (first,
// between, last, left out) and without value columns, with modifiers, a group
// and a bundle, for both table renderers: the default one and the own table of
// `compact`; and the total price hidden with line-items(show-column:). Each
// case is an invoice of its own; the test passes when all of them build. How
// the rows render: tests/theme/column-order and column-order-no-total.
#import "/tests/theme/column-order.typ": *

#let orders = (
  ("total-price", "quantity", "unit-price", "tax-rate"),
  ("quantity", "total-price", "unit-price", "tax-rate"),
  ("quantity", "unit-price", "total-price", "tax-rate"),
  ("quantity", "unit-price", "tax-rate", "total-price"),
  ("tax-rate", "total-price"),
  ("total-price",),
  ("quantity", "unit-price", "tax-rate"),
  (),
)

#for preset in (theme.classic, theme.compact) {
  for order in orders {
    invoice(
      theme: column-order-theme(order, preset: preset),
      locale: test-locale,
      ..party,
      column-order-items(),
    )
  }
  invoice(
    theme: preset,
    locale: test-locale,
    ..party,
    column-order-items(show-column: (total-price: false)),
  )
}
