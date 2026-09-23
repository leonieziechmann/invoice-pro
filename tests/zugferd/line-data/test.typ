// The note (BT-127), the date or period (BG-26) and the country of origin
// (BT-159) of an item: printed below its description and written into its
// invoice line. The note and the period exist in every profile with lines
// (BASIC and richer), the country of origin in EN 16931 and XRechnung only.

#import "/src/lib.typ": *
#import "/src/logic/calc-item.typ": origin-code
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/utils/text.typ": plain-text
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
)

#let day(month, day) = datetime(year: 2026, month: month, day: day)

// An invoice line period (BG-26) or invoicing period (BG-14) as written.
#let period(start, end) = (
  "<ram:BillingSpecifiedPeriod><ram:StartDateTime><udt:DateTimeString format=\"102\">"
    + start
    + "</udt:DateTimeString></ram:StartDateTime><ram:EndDateTime><udt:DateTimeString format=\"102\">"
    + end
    + "</udt:DateTimeString></ram:EndDateTime></ram:BillingSpecifiedPeriod>"
)

// --- 1. The country of origin: a country or an ISO 3166-1 code ---
#{
  assert.eq(origin-code(none), none)
  assert.eq(origin-code(""), none)
  assert.eq(origin-code(country.de), "DE")
  assert.eq(origin-code(country.fr()), "FR")
  assert.eq(origin-code(country.custom(code: "no")), "NO")
  assert.eq(origin-code("it"), "IT")
  assert.eq(origin-code([ch]), "CH")
  // "UK" is reserved for the United Kingdom, whose code is "GB"
  assert.eq(origin-code("UK"), "GB")
}

// --- 2. The XML states them in the invoice lines ---
#let items = [
  #line-items[
    #item(
      [Montage],
      price: 480,
      date: day(8, 3),
      note: [Einschließlich *Anfahrt*.\ Abnahme durch den Bauleiter.],
      origin: country.de,
    )
    #item(
      [Schulung],
      price: 900,
      date: (day(8, 10), day(8, 14)),
      origin: "it",
    )
    #item([Material], price: 60)
  ]
  #payment-goal(days: 14)
  #bank
]
#model-test(model => {
  assert.eq(model.lines.map(line => line.note), (
    "Einschließlich Anfahrt.\nAbnahme durch den Bauleiter.",
    none,
    none,
  ))
  assert.eq(model.lines.map(line => line.period), (
    (day(8, 3), day(8, 3)),
    (day(8, 10), day(8, 14)),
    none,
  ))
  assert.eq(model.lines.map(line => line.origin), ("DE", "IT", none))

  assert.eq(xml-elements(model, "ram:IncludedNote"), (
    "<ram:IncludedNote><ram:Content>Einschließlich Anfahrt.\nAbnahme durch den Bauleiter.</ram:Content></ram:IncludedNote>",
  ))
  // The periods of the lines, then the invoicing period that spans them
  assert.eq(xml-elements(model, "ram:BillingSpecifiedPeriod"), (
    period("20260803", "20260803"),
    period("20260810", "20260814"),
    period("20260803", "20260814"),
  ))
  assert.eq(xml-elements(model, "ram:OriginTradeCountry"), (
    "<ram:OriginTradeCountry><ram:ID>DE</ram:ID></ram:OriginTradeCountry>",
    "<ram:OriginTradeCountry><ram:ID>IT</ram:ID></ram:OriginTradeCountry>",
  ))
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ())

  // BASIC has the note and the period, but no country of origin: it is
  // only printed
  let m = model
  m.profile = resolve-profile("basic", "FR")
  assert.eq(xml-elements(m, "ram:IncludedNote").len(), 1)
  assert.eq(xml-elements(m, "ram:BillingSpecifiedPeriod").len(), 3)
  assert.eq(xml-elements(m, "ram:OriginTradeCountry"), ())
  assert.eq(rules(m, level: "warning"), ("IP-PROFILE-01",))
  assert.eq(diagnostic(m, "IP-PROFILE-01").field, "item.origin")

  // BASIC WL and MINIMUM have no invoice lines at all
  for id in ("basic-wl", "minimum") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(xml-elements(m, "ram:IncludedNote"), ())
    assert.eq(xml-elements(m, "ram:OriginTradeCountry"), ())
    assert.eq(rules(m, level: "warning"), ())
  }

  // A country EN 16931 does not know (BR-CL-15)
  m = model
  m.lines.at(1).origin = "XX"
  assert.eq(rules(m), ("BR-CL-15",))
  assert(diagnostic(m, "BR-CL-15").message.contains("\"XX\""))
  m.lines.at(1).origin = "EL"
  assert(diagnostic(m, "BR-CL-15").hint.contains("\"GR\""))
})[#items]

// --- 3. A period that ends before it starts (BR-30) ---
#model-test(model => {
  assert.eq(rules(model), ("BR-30",))
  let found = diagnostic(model, "BR-30")
  assert.eq(found.field, "item 1 (Wartung)")
  assert(found.message.contains("2026-08-14 to 2026-08-10"))
})[
  #line-items[#item([Wartung], price: 100, date: (day(8, 14), day(8, 10)))]
  #payment-goal(days: 14)
  #bank
]

// --- 4. Dates of items outside the service period of the invoice ---
// XRechnung requires the lines within the invoicing period (BG-14,
// PEPPOL-EN16931-R110 and R111); the other profiles get a warning
// (IP-PERIOD-02). Without `service-period`, the dates of the items are the
// service period and cannot leave it.
#let august = (day(8, 1), day(8, 31))
#let outside = [
  #line-items[
    #item([Juli], price: 100, date: (day(7, 28), day(8, 2)))
    #item([August], price: 100, date: (day(8, 3), day(8, 31)))
    #item([September], price: 100, date: day(9, 1))
    #item([Juli bis September], price: 100, date: (day(7, 31), day(9, 1)))
  ]
  #payment-goal(days: 14)
  #bank
]
#model-test(
  zugferd: "xrechnung",
  recipient: buyer-de,
  service-period: august,
  model => {
    assert.eq(rules(model), (
      "PEPPOL-EN16931-R110",
      "PEPPOL-EN16931-R110",
      "PEPPOL-EN16931-R111",
      "PEPPOL-EN16931-R111",
    ))
    let r110 = diagnostic(model, "PEPPOL-EN16931-R110")
    assert.eq(r110.field, "item 1 (Juli)")
    assert.eq(
      r110.message,
      "The date of the item (2026-07-28 to 2026-08-02) is outside the service period of the invoice (2026-08-01 to 2026-08-31).",
    )
    assert.eq(
      diagnostic(model, "PEPPOL-EN16931-R111").field,
      "item 3 (September)",
    )

    // EN 16931 has no such rule: a warning, one per item
    let m = model
    m.profile = resolve-profile("en16931", "DE")
    assert.eq(rules(m), ())
    assert.eq(rules(m, level: "warning"), (
      "IP-PERIOD-02",
      "IP-PERIOD-02",
      "IP-PERIOD-02",
    ))
  },
)[#outside]

// A service period of one day is the delivery date (BT-72), not BG-14: the
// rules of XRechnung do not apply, the warning does
#model-test(
  zugferd: "xrechnung",
  recipient: buyer-de,
  service-period: day(8, 31),
  model => {
    assert.eq(model.delivery.period, none)
    assert.eq(rules(model), ())
    assert.eq(rules(model, level: "warning"), ("IP-PERIOD-02",))
    assert.eq(
      diagnostic(model, "IP-PERIOD-02").message,
      "The date of the item (2026-08-15) is outside the service period of the invoice (2026-08-31).",
    )
  },
)[
  #line-items[#item([Lieferung], price: 100, date: day(8, 15))]
  #payment-goal(days: 14)
  #bank
]

// --- 5. Printed below the description, each on a line of its own ---
#let printed-test(check, body) = invoice(
  theme: () => (
    themes.blank()
      + (
        line-items: (ctx, view, body) => {
          check(view.items)
          []
        },
      )
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-fr,
  body,
)
#printed-test(items => {
  let described = items.map(item => (
    item.has-description,
    plain-text(item.description, keep-newlines: true),
  ))
  assert.eq(described, (
    (true, "Vor Ort\nEinschließlich Anfahrt.\nUrsprungsland: DE"),
    (true, "Ursprungsland: IT"),
    (true, "Geprüft"),
    (false, ""),
  ))
})[
  #line-items[
    #item(
      [Montage],
      description: [Vor Ort],
      note: "Einschließlich Anfahrt.",
      origin: country.de,
      price: 100,
    )
    #item([Schulung], origin: "IT", price: 100)
    #item([Material], note: [Geprüft], price: 100)
    #item([Fahrt], price: 100)
  ]
]
