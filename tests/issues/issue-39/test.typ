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
#import "/src/themes/components/line-items/line-items.typ": (
  render-line-items as generic-render-line-items,
)

// 1. Small business in exclusive mode: elements.taxes must be empty
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: generic-render-line-items.with(
        render-totals-body: (ctx, data, styles, elements) => {
          assert.eq(
            elements.taxes.len(),
            0,
            message: "Expected elements.taxes to be empty for small business (0% tax), got "
              + repr(elements.taxes),
          )
          [Totals verified]
        },
      ),
    ),
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

// 2. Small business in inclusive (B2C) mode: elements.taxes must be empty
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: generic-render-line-items.with(
        render-totals-body: (ctx, data, styles, elements) => {
          assert.eq(
            elements.taxes.len(),
            0,
            message: "Expected elements.taxes to be empty in inclusive mode for small business, got "
              + repr(elements.taxes),
          )
          [Totals B2C verified]
        },
      ),
    ),
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

// 3. Mixed taxes: 19% VAT and 0% exempt -> only 19% tax should be in elements.taxes
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: generic-render-line-items.with(
        render-totals-body: (ctx, data, styles, elements) => {
          assert.eq(
            elements.taxes.len(),
            1,
            message: "Expected exactly 1 tax (19%) in elements.taxes, got "
              + repr(elements.taxes.len()),
          )
          [Mixed taxes verified]
        },
      ),
    ),
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

// 4. Full DIN-5008 German personal invoice with small-biz exemption renders cleanly
#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
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
