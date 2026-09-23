// Source: docs/docs/api-reference/locale/base.md — "Example: Schema Inspection and Override"
#import "/src/lib.typ": invoice, locale
#import "/tests/docs/prelude.typ": body, party

#let custom-lang = (
  payment: (
    // Update the prompt payment phrasing
    deadline-soon: "due immediately upon receipt",
  ),
)

#show: invoice.with(
  locale: locale.build-locale(
    custom-lang,
    locale.region.de, // German formatting and taxes
  ),
  ..party,
)

#body()
