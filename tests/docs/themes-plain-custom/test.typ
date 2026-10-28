// Source: docs/docs/themes/plain.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.plain.with({
    import theme.custom: *
    stationery("pre-printed") // the paper carries name, address and legal data
    area("letterhead", none) // so neither the sender block ..
    area("footer", none) // .. nor the registration footer is printed again
    page(margin: (top: 50mm, bottom: 35mm)) // keep clear of the printed zones
  }),
  ..party,
)
#body()
