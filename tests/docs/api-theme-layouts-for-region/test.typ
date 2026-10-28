// Source: docs/docs/api-reference/theme/layouts.md — "Layout by Region (region functions)"
#import "/tests/docs/prelude.typ": *

#let job = (region: "us") // e.g. json("job.json")

#show: invoice.with(
  theme: theme.classic.with(
    layout: theme.layout.digital-for-region(job.region),
  ),
  ..party,
)
#body()

#assert.eq(theme.layout.digital-for-region("us").name, "us-letter-digital")
#assert.eq(theme.layout.for-region("CH").name, "sn-010130-right")
#assert.eq(theme.layout.for-region("nl").name, "din-5008-a")
