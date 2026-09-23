// The service period is resolved once for the printed invoice
// (`references.service-time`) and the e-invoice (BT-72 or BG-14): the
// invoice's `service-period`, else the dates of the items (items without a
// date do not count), else the invoice date. A service period printed as a
// text of its own cannot reach the XML (IP-PERIOD-01).

#import "/src/lib.typ": *
#import "/src/logic/service-period.typ": (
  format-service-period, resolve-service-period,
)
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
  xml-values,
)

#let day(month, day) = datetime(year: 2026, month: month, day: day)
#let invoice-date = day(9, 1)

// --- 1. Resolving the service period ---
#{
  let resolve(..items, service-period: none) = {
    let period = resolve-service-period(
      items.pos().map(date => (date: date)),
      invoice-date,
      service-period: service-period,
    )
    if period == none { none } else {
      (period.start, period.end, period.source)
    }
  }
  // Undated items do not count when others are dated
  assert.eq(resolve(day(8, 15), none), (day(8, 15), day(8, 15), "items"))
  assert.eq(resolve(none, (day(7, 1), day(7, 31)), auto), (
    day(7, 1),
    day(7, 31),
    "items",
  ))
  assert.eq(resolve(day(8, 20), day(8, 3), (day(8, 5), day(8, 10))), (
    day(8, 3),
    day(8, 20),
    "items",
  ))
  // The invoice date only when nothing is dated
  assert.eq(resolve(none, auto), (invoice-date, invoice-date, "invoice-date"))
  assert.eq(resolve(), (invoice-date, invoice-date, "invoice-date"))
  // The invoice's service period overrides the items
  assert.eq(resolve(day(8, 15), service-period: (day(6, 1), day(6, 30))), (
    day(6, 1),
    day(6, 30),
    "invoice",
  ))
  assert.eq(resolve(service-period: day(6, 12)), (
    day(6, 12),
    day(6, 12),
    "invoice",
  ))
  assert.eq(resolve-service-period((), none), none)

  let format = date => date.display("[day].[month].[year]")
  let period(start, end) = (start: start, end: end, source: "items")
  assert.eq(
    format-service-period(period(day(8, 1), day(8, 31)), format),
    "01.08.2026 – 31.08.2026",
  )
  assert.eq(
    format-service-period(period(day(8, 1), day(8, 1)), format),
    "01.08.2026",
  )
}

// --- 2. The XML states the printed service period ---
// A theme that hands the printed references to `check`.
#let printed-test(check, ..args, body) = invoice(
  theme: () => (
    themes.blank() + (document: (ctx, _) => check(ctx.references))
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-fr,
  invoice-nr: "2026-01",
  date: invoice-date,
  references: (references.service-time(),),
  ..args,
  body,
)

// One dated and one undated item: the date of the dated item (finding
// amounts-delivery-date-mismatch; the XML stated 15.08. to 01.09.)
#let mixed = [
  #line-items[
    #item([A], price: 100, date: day(8, 15))
    #item([B], price: 100)
  ]
  #payment-goal(days: 14)
  #bank
]
#printed-test(refs => {
  assert.eq(refs, (("Leistungszeitraum", "15.08.2026"),))
  []
})[#mixed]
#model-test(date: invoice-date, model => {
  assert.eq(model.delivery.date, day(8, 15))
  assert.eq(model.delivery.period, none)
  assert.eq(model.delivery.text, "15.08.2026")
  assert.eq(xml-elements(model, "ram:BillingSpecifiedPeriod"), ())
  assert.eq(xml-elements(model, "ram:ActualDeliverySupplyChainEvent"), (
    "<ram:ActualDeliverySupplyChainEvent><ram:OccurrenceDateTime><udt:DateTimeString format=\"102\">20260815</udt:DateTimeString></ram:OccurrenceDateTime></ram:ActualDeliverySupplyChainEvent>",
  ))
  assert.eq(rules(model), ())
})[#mixed]

// A group dated with a period and an undated item: the period of the group
#let grouped = [
  #line-items[
    #group([Juli], date: (day(7, 1), day(7, 31)))[
      #item([Wartung], price: 100)
    ]
    #item([Material], price: 50)
  ]
  #payment-goal(days: 14)
  #bank
]
#printed-test(refs => {
  assert.eq(refs, (("Leistungszeitraum", "01.07.2026 – 31.07.2026"),))
  []
})[#grouped]
#model-test(date: invoice-date, model => {
  assert.eq(model.delivery.date, none)
  assert.eq(model.delivery.period, (day(7, 1), day(7, 31)))
  assert.eq(
    xml-elements(model, "ram:BillingSpecifiedPeriod"),
    (
      "<ram:BillingSpecifiedPeriod><ram:StartDateTime><udt:DateTimeString format=\"102\">20260701</udt:DateTimeString></ram:StartDateTime><ram:EndDateTime><udt:DateTimeString format=\"102\">20260731</udt:DateTimeString></ram:EndDateTime></ram:BillingSpecifiedPeriod>",
    ),
  )
})[#grouped]

// No item has a date: the invoice date
#model-test(date: invoice-date, model => {
  assert.eq(model.delivery.date, invoice-date)
  assert.eq(model.delivery.source, "invoice-date")
})[
  #line-items[#item([A], price: 100)]
  #payment-goal(days: 14)
  #bank
]

// --- 3. The invoice's service period overrides the items ---
#let june = (day(6, 1), day(6, 30))
#printed-test(service-period: june, refs => {
  assert.eq(refs, (("Leistungszeitraum", "01.06.2026 – 30.06.2026"),))
  []
})[#mixed]
#model-test(date: invoice-date, service-period: june, model => {
  assert.eq(model.delivery.period, june)
  assert.eq(model.delivery.source, "invoice")
  assert.eq(rules(model, level: "warning"), ())
})[
  #line-items[#item([Wartung Juni], price: 100)]
  #payment-goal(days: 14)
  #bank
]
#model-test(date: invoice-date, service-period: day(6, 12), model => {
  assert.eq(model.delivery.date, day(6, 12))
  assert.eq(model.delivery.period, none)
})[
  #line-items[#item([Lieferung], price: 100)]
  #payment-goal(days: 14)
  #bank
]

// --- 4. A service period printed as a text of its own (IP-PERIOD-01) ---
// The references are evaluated while the invoice is drawn, so these tests
// read the diagnostics of the e-invoice from the report of the theme.
#let report-test(check, ..args, body) = invoice(
  theme: () => (
    themes.blank()
      + (
        zugferd-report: (ctx, result) => {
          check(result)
          []
        },
      )
  ),
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "report",
  sender: seller,
  recipient: buyer-fr,
  invoice-nr: "2026-01",
  date: invoice-date,
  ..args,
  body,
)
#let warnings(result) = (
  result.diagnostics.filter(d => d.level == "warning").map(d => d.rule)
)

#report-test(
  references: (references.service-time(value: "Juni 2026"),),
  result => {
    assert.eq(result.model.delivery.printed, "Juni 2026")
    assert.eq(warnings(result), ("IP-PERIOD-01",))
    let d = result.diagnostics.find(d => d.rule == "IP-PERIOD-01")
    assert.eq(d.field, "references")
    assert.eq(
      d.message,
      "The invoice prints the service period \"Juni 2026\", but the e-invoice states \"01.09.2026\" (BT-72), the invoice date, as no item has a date.",
    )
    assert(d.hint.starts-with("Set `service-period` on the invoice"))
  },
)[
  #line-items[#item([Wartung Juni], price: 100)]
  #payment-goal(days: 14)
  #bank
]
// ... also as a reference of its own with the label of the service period
#report-test(
  references: (("Leistungszeitraum", "Juni 2026"),),
  result => {
    assert.eq(warnings(result), ("IP-PERIOD-01",))
    assert(
      result.diagnostics.first().message.contains("\"30.06.2026\" (BT-72)."),
    )
  },
)[
  #line-items[#item([Wartung Juni], price: 100, date: day(6, 30))]
  #payment-goal(days: 14)
  #bank
]
// MINIMUM states no service period
#report-test(
  zugferd: "minimum",
  references: (("Leistungszeitraum", "Juni 2026"),),
  result => assert.eq(warnings(result), ()),
)[
  #line-items[#item([Wartung Juni], price: 100)]
  #payment-goal(days: 14)
  #bank
]
// `references.service-time()` prints the service period of the XML. (The
// report is only shown with diagnostics: the unit "STK" gives a warning.)
#report-test(
  service-period: june,
  references: (references.service-time(),),
  result => {
    assert.eq(result.model.delivery.printed, "01.06.2026 – 30.06.2026")
    assert.eq(result.model.delivery.text, "01.06.2026 – 30.06.2026")
    assert.eq(warnings(result), ("IP-UNIT-01",))
  },
)[
  #line-items[
    #item([Wartung Juni], price: 100)
    #item([Schrauben], price: 1, quantity: 10, unit: "STK")
  ]
  #payment-goal(days: 14)
  #bank
]
