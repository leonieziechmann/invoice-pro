// Source: docs/docs/api-reference/theme/customization.md — "Options"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    items-table(
      zebra: (none, none),
      header-fill: rgb("#1f2937"),
      row-rule: 0.5pt + luma(200),
    )
    totals(fill: rgb("#1f2937"), width: 60%)
    title(arrange: "stack")
    page-number(format: (ctx, current, total) => [#current / #total])
    bank-details(qr-size: 30mm)
  }),
  ..party,
)
#body(n: 6)
