// Source: docs/docs/api-reference/locale/custom.md — "Example: Building a "Europe East" Package"
// lang/pl.typ, region/pl.typ and lib.typ are the other three code blocks of the page.
#import "/src/lib.typ": invoice
#import "/tests/docs/prelude.typ": body, party
#import "lib.typ": pl-pl

#show: invoice.with(
  locale: pl-pl,
  ..party,
)

#body()
