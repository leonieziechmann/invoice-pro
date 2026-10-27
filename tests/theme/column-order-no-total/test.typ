/// [ppi: 60]

// items-table(column-order:) without the total price ("a column left out is
// never shown"), as in the table of `compact`: a modifier row shows its label
// and percentage across the value columns, the item subtotal is left out and
// the group subtotal shows its label; the totals state every amount. The rows
// subtracted from the missing total column ("cannot subtract integer from
// none").
#import "/tests/theme/column-order.typ": *

#show: invoice.with(
  theme: column-order-theme(("quantity", "unit-price", "tax-rate")),
  locale: test-locale,
  ..party,
)
#column-order-items()
