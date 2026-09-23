// Source: docs/docs/api-reference/locale/index.md — "Example: Custom Currency Formatting"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  locale: locale.de-de.with(
    locale.custom.format(
      currency: val => str(calc.round(val, digits: 2)) + " EUR",
      currency-fine: val => str(val) + " EUR",
    ),
  ),
  ..party,
)
#body()
