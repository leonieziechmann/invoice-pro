// Regression test for GitHub issue #39
// https://github.com/leonieziechmann/invoice-pro/issues/39
//
// Bug reported:
// With `tax-exempt-small-biz: true`, VAT was displayed as "0%" in the final
// tax listing of the totals summary. For German personal (and B2C) invoices,
// displaying 0% VAT implies a zero/reduced tax rate rather than statutory tax
// exemption. 0% VAT should be omitted from the final tax listing, and the
// entire tax section collapsed when no other taxes exist.

#import "/src/lib.typ": *

// The 0% filter runs in measure: the totals row model (`view.totals.rows`),
// which every totals renderer draws, has no row for a 0% rate. A wrap of the
// `totals` part checks the tax rows, then renders the default totals. Every
// check records its scenario `id`.
//
// The scenarios use minimal invoice data, so they render without validation
// feedback (`validation: none`): the feedback is not what these checks are about.
#let check-tax-rows(id, expected, message) = theme.plain.with(
  theme.custom.wrap("totals", (ctx, view, inner) => {
    let taxes = view.totals.rows.filter(r => r.kind == "tax")
    assert.eq(
      taxes.len(),
      expected,
      message: message + ", got " + repr(taxes),
    )
    [#metadata(id)<issue-39-checked>]
    inner(ctx, view)
  }),
)

// 1. Small business in exclusive mode: no tax row
#{
  let doc = invoice(
    theme: check-tax-rows(
      1,
      0,
      "Expected no tax row for small business (0% tax)",
    ),
    validation: none,
    locale: locale.de-de,
    sender: (
      name: "Kleinunternehmer",
      address: "Musterstr. 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Kunde",
      address: "Hauptstr. 2",
      city: "Berlin",
      country: country.de,
    ),
    tax-exempt-small-biz: true,
  )[
    #line-items[
      #item([Beratung], price: 150.00)
    ]
  ]
  [#doc]
}

// 2. Small business in inclusive (B2C) mode: no tax row
#{
  let doc = invoice(
    theme: check-tax-rows(
      2,
      0,
      "Expected no tax row in inclusive mode for small business",
    ),
    validation: none,
    locale: locale.de-de,
    tax-mode: "inclusive",
    sender: (
      name: "Kleinunternehmer",
      address: "Musterstr. 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Privatkunde",
      address: "Hauptstr. 2",
      city: "Berlin",
      country: country.de,
    ),
    tax-exempt-small-biz: true,
  )[
    #line-items[
      #item([Dienstleistung B2C], price: 80.00)
    ]
  ]
  [#doc]
}

// 3. Mixed taxes: 19% VAT and 0% exempt -> only the 19% tax gets a row
#{
  let doc = invoice(
    theme: check-tax-rows(
      3,
      1,
      "Expected exactly 1 tax row (19%)",
    ),
    validation: none,
    locale: locale.de-de,
    sender: (
      name: "Firma",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Kunde",
      address: "Str 2",
      city: "Berlin",
      country: country.de,
    ),
  )[
    #line-items[
      #item([Reguläres Produkt], price: 100.00, tax: tax.vat(19%))
      #item(
        [Steuerfreie Leistung],
        price: 50.00,
        tax: tax.exempt(grounds: "§ 4 Nr. 21 UStG"),
      )
    ]
  ]
  [#doc]
}

// Every scenario above must have run its check.
#context {
  let ran = query(<issue-39-checked>).map(m => m.value).dedup()
  assert.eq(ran, (1, 2, 3), message: "checked scenarios: " + repr(ran))
}

// 4. Full classic German personal invoice with small-biz exemption renders cleanly
#show: invoice.with(
  theme: theme.classic.with(theme.custom.fonts(body: "libertinus serif")),
  locale: locale.de-de,
  tax-mode: "inclusive",
  tax-exempt-small-biz: true,
  sender: (
    name: "Max Mustermann",
    address: "Musterweg 10",
    city: "10115 Berlin",
    country: country.de,
  ),
  recipient: (
    name: "Erika Mustermann",
    address: "Kundenallee 20",
    city: "80331 München",
    country: country.de,
  ),
  invoice-nr: "RE-2026-0039",
  date: datetime(year: 2026, month: 9, day: 4),
)

#line-items[
  #item([Webdesign & Entwicklung], quantity: 1, price: 500.00)
  #item([Wartungspauschale], quantity: 1, price: 50.00)
]

#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "BANK123X",
)
