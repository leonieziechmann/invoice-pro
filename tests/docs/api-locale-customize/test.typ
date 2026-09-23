// Source: docs/docs/api-reference/locale/index.md — "Customizing Locales"
#import "/src/lib.typ": invoice, locale
#import "/tests/docs/prelude.typ": body, party

#show: invoice.with(
  locale: locale.en-de.with(
    locale.custom.document(
      invoice: "Proforma Invoice",
      page: (current, total) => [#current / #total],
    ),
    locale.custom.line-items(position: "Pos.", unit-price: "Price/Unit"),
  ),
  ..party,
)

#body(n: 30)
