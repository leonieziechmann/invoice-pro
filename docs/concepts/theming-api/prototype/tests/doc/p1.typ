#import "prelude.typ": *
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(
      color: rgb("#0f766e"),
      font: ("Inter", "Liberation Sans", "Libertinus Serif"),
      logo: image("logo.svg", alt: "Studio Lina Berg"),
    ),
    theme.custom.marks(none),
  ),
  locale: locale.de-de,
  tax-exempt-small-biz: true,
  ..party,
)
#body()
