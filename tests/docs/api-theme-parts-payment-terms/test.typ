// Source: docs/docs/api-reference/theme/parts.md — "Body Views"
#import "/tests/docs/prelude.typ": *

#let pay-card(ctx, view) = {
  let fill = ctx.theme.tokens.colors.accent.lighten(88%)
  block(fill: fill, inset: 1em, width: 100%)[
    Please pay *#view.amount.text* #view.deadline.
  ]
}

#show: invoice.with(
  locale: locale.en-de,
  theme: theme.corporate.with(theme.custom.part("payment-terms", pay-card)),
  ..party,
)
#body()
