// Source: docs/docs/api-reference/theme/index.md — "Passing a Theme (by name)"
#import "/tests/docs/prelude.typ": *

#let name = sys.inputs.at("preset", default: "classic")
#show: invoice.with(theme: dictionary(theme).at(name), ..party)
#body()
