// Source: docs/docs/themes/plain.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.plain, // no letterhead and no marks: everything in the text flow
  locale: locale.en-de,
  tax-exempt-small-biz: true, // small business: no VAT, the legal note is added
  sender: (
    name: "Clara Weiss Translations",
    address: "Kolberger Straße 4",
    city: "24105 Kiel",
    tax-nr: "20/123/45678",
  ),
  recipient: (
    name: "Nordwind Travel GmbH",
    address: "Holstenstraße 21",
    city: "24103 Kiel",
  ),
  invoice-nr: "CW-2026-038",
)

#line-items[
  #item(
    [Translation of the 2027 catalogue, German to English],
    quantity: 2140,
    unit: "lines",
    price: 1.45,
  )
  #item(
    [Proofreading, October newsletter],
    quantity: 2,
    unit: unit.hour,
    price: 55,
  )
]

#payment-terms(days: 14)
#bank-details(
  bank: "Förde Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Clara Weiss")
