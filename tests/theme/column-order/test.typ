/// [ppi: 60]

// items-table(column-order:) with columns after the total price: the
// percentage of a modifier sits in the column before the total, its amount,
// the subtotal of the item and the subtotal of the group in the total column,
// and the columns after the total stay empty. The empty cells after the total
// of a modifier row had no body, which stopped the build ("missing argument:
// body"). No total column: tests/theme/column-order-no-total; every order and
// both table renderers: tests/theme/column-order-matrix.
#import "/tests/theme/column-order.typ": *

#show: invoice.with(
  theme: column-order-theme((
    "quantity",
    "total-price",
    "unit-price",
    "tax-rate",
  )),
  locale: test-locale,
  ..party,
)
#column-order-items()
