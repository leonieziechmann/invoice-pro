// Source: docs/docs/api-reference/invoice/validation.md — "Localised Report"
// invoice-nr: none makes the custom marker visible.
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  locale: locale.en-de.with((
    strings: (validation: (marker: field => [‹to do: #field›])),
  )),
  ..party,
  invoice-nr: none, // shows the marker
)
#body()
