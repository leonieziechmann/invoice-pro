#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

// 1. Single ground: Reverse Charge with custom grounds string
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: (ctx, data, body) => {
        assert.eq(data.taxes.len(), 1)
        let t = data.taxes.first()
        assert.eq(t.category, [AE])
        assert.eq(t.marker, "*")
        assert.eq(
          t.grounds,
          "Steuerschuldnerschaft des Leistungsempfängers (Reverse Charge)",
        )
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Agency DE",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client FR",
      address: "Rue 1",
      city: "Paris",
      country: country.fr,
    ),
    tax: tax.reverse-charge(
      grounds: "Steuerschuldnerschaft des Leistungsempfängers (Reverse Charge)",
    ),
  )[
    #line-items[
      #item([Consulting], price: 1000.00)
    ]
  ]
  [#doc]
}

// 2. Multiple distinct grounds on one invoice: each unique ground gets its own marker
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: (ctx, data, body) => {
        assert.eq(data.taxes.len(), 2)
        let t-rc = data.taxes.find(t => t.category == [AE])
        let t-ex = data.taxes.find(t => t.category == [E])
        assert.ne(t-rc, none)
        assert.ne(t-ex, none)
        assert.eq(t-rc.marker, "*")
        assert.eq(t-rc.grounds, "Reason A (Reverse Charge)")
        assert.eq(t-ex.marker, "**")
        assert.eq(t-ex.grounds, "Reason B (Exempt)")
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Agency DE",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client FR",
      address: "Rue 1",
      city: "Paris",
      country: country.fr,
    ),
  )[
    #line-items[
      #item(
        [Service 1],
        price: 500.00,
        tax: tax.reverse-charge(grounds: "Reason A (Reverse Charge)"),
      )
      #item(
        [Service 2],
        price: 300.00,
        tax: tax.exempt(grounds: "Reason B (Exempt)"),
      )
    ]
  ]
  [#doc]
}

// 3. Shared ground across different items: same ground receives the SAME marker
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: (ctx, data, body) => {
        assert.eq(data.taxes.len(), 1)
        let t = data.taxes.first()
        assert.eq(t.marker, "*")
        assert.eq(t.grounds, "Shared Reason")
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Agency DE",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client FR",
      address: "Rue 1",
      city: "Paris",
      country: country.fr,
    ),
  )[
    #line-items[
      #item(
        [Service 1],
        price: 500.00,
        tax: tax.reverse-charge(grounds: "Shared Reason"),
      )
      #item(
        [Service 2],
        price: 300.00,
        tax: tax.reverse-charge(grounds: "Shared Reason"),
      )
    ]
  ]
  [#doc]
}

// 4. Mixed taxable (no grounds) and exempt (with grounds): only exempt gets a marker
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: (ctx, data, body) => {
        assert.eq(data.taxes.len(), 2)
        let t-vat = data.taxes.find(t => t.category == [S])
        let t-rc = data.taxes.find(t => t.category == [AE])
        assert.eq(t-vat.marker, none)
        assert.eq(t-vat.grounds, none)
        assert.eq(t-rc.marker, "*")
        assert.eq(t-rc.grounds, "Reverse Charge Ground")
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Agency DE",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client FR",
      address: "Rue 1",
      city: "Paris",
      country: country.fr,
    ),
  )[
    #line-items[
      #item([Standard Item], price: 200.00, tax: tax.vat(19%))
      #item(
        [RC Item],
        price: 400.00,
        tax: tax.reverse-charge(grounds: "Reverse Charge Ground"),
      )
    ]
  ]
  [#doc]
}

// 5. Default tax.reverse-charge(): grounds defaults to "Reverse charge" with marker "*"
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: (ctx, data, body) => {
        assert.eq(data.taxes.len(), 1)
        let t = data.taxes.first()
        assert.eq(t.category, [AE])
        assert.eq(t.marker, "*")
        assert.eq(t.grounds, "Reverse charge")
        body
      },
    ),
    locale: locale.en-de,
    sender: (
      name: "Agency DE",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client FR",
      address: "Rue 1",
      city: "Paris",
      country: country.fr,
    ),
    tax: tax.reverse-charge(),
  )[
    #line-items[
      #item([Consulting], price: 1000.00)
    ]
  ]
  [#doc]
}

// 6. Small business exemption: marker links to legal grounds
#{
  let doc = invoice(
    theme: themes.blank.with(
      line-items: (ctx, data, body) => {
        assert.eq(data.taxes.len(), 1)
        let t = data.taxes.first()
        assert.eq(t.category, [O])
        assert.eq(t.marker, "*")
        assert.eq(
          t.grounds,
          "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
        )
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Kleinunternehmer",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client",
      address: "Str 2",
      city: "Berlin",
      country: country.de,
    ),
    tax-exempt-small-biz: true,
  )[
    #line-items[
      #item([Small Biz Item], price: 100.00)
    ]
  ]
  [#doc]
}

// 7. User's exact snippet: DIN-5008 default theme rendering
#{
  let doc = invoice(
    tax: tax.reverse-charge(
      grounds: "Steuerschuldnerschaft des Leistungsempfängers (Reverse Charge)",
    ),
    sender: (
      name: "Agency DE",
      address: "Str 1",
      city: "Berlin",
      country: country.de,
    ),
    recipient: (
      name: "Client FR",
      address: "Rue 1",
      city: "Paris",
      country: country.fr,
    ),
    date: datetime.today(),
  )[
    #line-items[#item([Consulting], price: 1000.00)]
  ]
  [#doc]
}
