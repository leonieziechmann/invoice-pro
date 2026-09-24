// The service period is resolved once for the printed invoice
// (`references.service-time`) and the e-invoice (BT-72 or BG-14): the
// invoice's `service-period`, else the dates of the items (items without a
// date do not count), else the invoice date, except on a credit note, which
// then states none. A service period printed as a text of its own cannot
// reach the XML (IP-PERIOD-01).

#import "/src/lib.typ": *
#import "/src/utils/text.typ": plain-text
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
// A theme that hands the printed references to `check`, as plain text (the
// printed service period is marked content, see `references.service-time`).
#let printed-test(check, ..args, body) = invoice(
  theme: () => (
    themes.blank()
      + (
        document: (ctx, _) => check(ctx.references.map(((label, value)) => (
          label,
          plain-text(value),
        ))),
      )
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
  // Only the dated line has a period (BG-26), the invoice has none (BG-14)
  assert.eq(xml-elements(model, "ram:BillingSpecifiedPeriod"), (
    "<ram:BillingSpecifiedPeriod><ram:StartDateTime><udt:DateTimeString format=\"102\">20260815</udt:DateTimeString></ram:StartDateTime><ram:EndDateTime><udt:DateTimeString format=\"102\">20260815</udt:DateTimeString></ram:EndDateTime></ram:BillingSpecifiedPeriod>",
  ))
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
  // The period of the line of the item in the group (BG-26), then the
  // invoicing period (BG-14)
  let july = "<ram:BillingSpecifiedPeriod><ram:StartDateTime><udt:DateTimeString format=\"102\">20260701</udt:DateTimeString></ram:StartDateTime><ram:EndDateTime><udt:DateTimeString format=\"102\">20260731</udt:DateTimeString></ram:EndDateTime></ram:BillingSpecifiedPeriod>"
  assert.eq(xml-elements(model, "ram:BillingSpecifiedPeriod"), (july, july))
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
// ... but not on a credit note, which amends an invoice: its own date is not
// the date of the supply, so neither the XML nor the printed invoice states
// one
#let undated = [
  #line-items[#item([A], price: 100)]
  #payment-goal(days: 14)
  #bank
]
#model-test(
  date: invoice-date,
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  model => {
    assert.eq(model.delivery.date, none)
    assert.eq(model.delivery.period, none)
    assert.eq(model.delivery.source, none)
    assert.eq(xml-elements(model, "ram:ActualDeliverySupplyChainEvent"), ())
    assert.eq(xml-elements(model, "ram:BillingSpecifiedPeriod"), ())
    assert.eq(rules(model), ())
    assert.eq(rules(model, level: "warning"), ())
    // XRechnung recommends the date of the supply (BR-DE-TMP-32, information
    // in its Schematron): a warning that names `service-period`
    let m = model
    m.profile = resolve-profile("xrechnung", "DE")
    assert("BR-DE-TMP-32" in rules(m, level: "warning"))
    assert.eq(diagnostic(m, "BR-DE-TMP-32").field, "service-period")
  },
)[#undated]
#printed-test(
  references: auto,
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  refs => {
    assert("Leistungszeitraum" not in refs.map(ref => ref.first()))
    []
  },
)[#undated]
#printed-test(
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  refs => {
    assert.eq(refs, ())
    []
  },
)[#undated]
// ... unless its items are dated
#model-test(
  date: invoice-date,
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  model => {
    assert.eq(model.delivery.date, day(8, 15))
    assert.eq(model.delivery.source, "items")
    let m = model
    m.profile = resolve-profile("xrechnung", "DE")
    assert("BR-DE-TMP-32" not in rules(m, level: "warning"))
  },
)[#mixed]

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
  // MINIMUM states no service period, which is reported as a warning
  let m = model
  m.profile = resolve-profile("minimum", "FR")
  assert.eq(rules(m, level: "warning"), ("IP-PROFILE-01",))
  assert.eq(diagnostic(m, "IP-PROFILE-01").field, "service-period")
  // ... but only for the invoice's own service period
  m.delivery.source = "items"
  assert.eq(rules(m, level: "warning"), ())
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

// The default references print the service period of the invoice, which
// the e-invoice states, after the tax numbers, with net and gross prices
#printed-test(references: auto, service-period: june, refs => {
  assert.eq(refs, (
    ("Steuernummer", "123/456/78901"),
    ("USt-IdNr.", "DE123456789"),
    ("Empfänger:in USt-IdNr.", "FR99123456789"),
    ("Leistungszeitraum", "01.06.2026 – 30.06.2026"),
  ))
  []
})[#mixed]
#printed-test(
  references: auto,
  tax-mode: "inclusive",
  service-period: day(6, 12),
  refs => {
    assert.eq(refs.last(), ("Leistungszeitraum", "12.06.2026"))
    []
  },
)[#mixed]
// A seller in Germany prints the date of the supply in any case (§ 14
// Abs. 4 Satz 1 Nr. 6 UStG): the dates of the items, or the invoice date
#printed-test(references: auto, refs => {
  assert.eq(refs.last(), ("Leistungszeitraum", "15.08.2026"))
  []
})[#mixed]
#printed-test(references: auto, refs => {
  assert.eq(refs.last(), ("Leistungszeitraum", "01.09.2026"))
  []
})[
  #line-items[#item([A], price: 100)]
]
// A seller elsewhere only the invoice's own `service-period`: the dates of
// the items are printed with the items, and the invoice date is the date of
// the invoice (Art. 226 No. 7 of the VAT Directive)
#printed-test(
  references: auto,
  sender: seller + (country: country.at, vat-id: "ATU12345675"),
  refs => {
    assert.eq(refs.map(ref => ref.first()), (
      "Steuernummer",
      "USt-IdNr.",
      "Empfänger:in USt-IdNr.",
    ))
    []
  },
)[#mixed]

// --- 4. The printed service period and the XML (IP-PERIOD-01) ---
// A text of its own where the XML states the invoice date contradicts it: an
// error.
// The references are evaluated while the invoice is drawn, so these tests
// read the diagnostics of the e-invoice from the report of the theme. The
// report is only shown with diagnostics; each shown report leaves a marker,
// which the end of the file counts.
#let report-test(check, ..args, body) = invoice(
  theme: () => (
    themes.blank()
      + (
        zugferd-report: (ctx, result) => {
          check(result)
          [#metadata(none)<report-checked>]
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
#let errors(result) = (
  result.diagnostics.filter(d => d.level == "error").map(d => d.rule)
)
// An undated item with a unit only EN 16931 knows, which gives a warning
// (IP-UNIT-01), so that the report is shown.
#let screws = item([Schrauben], price: 1, quantity: 10, unit: "STK")

#report-test(
  references: (references.service-time(value: "Juni 2026"),),
  result => {
    assert.eq(result.model.delivery.printed, "Juni 2026")
    assert.eq(errors(result), ("IP-PERIOD-01",))
    assert.eq(warnings(result), ())
    let d = result.diagnostics.find(d => d.rule == "IP-PERIOD-01")
    assert.eq(d.field, "references")
    assert.eq(
      d.message,
      "The invoice prints the service period \"Juni 2026\", but the e-invoice states \"01.09.2026\" (BT-72), the invoice date, as no item has a date.",
    )
    assert(d.hint.starts-with("Set `service-period` on the invoice"))
    assert(
      d.hint.ends-with(
        "print it with `references.service-time()` without `value`, which prints the service period of the e-invoice.",
      ),
    )
  },
)[
  #line-items[#item([Wartung Juni], price: 100)]
  #payment-goal(days: 14)
  #bank
]
// A reference of its own with the title of the service period is compared
// as well. Besides a dated item it may name the same period in other words:
// a warning.
#report-test(
  references: (("Leistungszeitraum", "Juni 2026"),),
  result => {
    assert.eq(errors(result), ())
    assert.eq(warnings(result), ("IP-PERIOD-01",))
    assert.eq(
      result.diagnostics.first().message,
      "The invoice prints the service period \"Juni 2026\" as a text of its own, but the e-invoice states \"30.06.2026\" (BT-72), from the dates of the items. Make sure that both name the same period.",
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
  // A note, which MINIMUM cannot state (IP-PROFILE-01), shows the report.
  notes: [Wartung],
  result => assert.eq(result.diagnostics.map(d => d.rule), ("IP-PROFILE-01",)),
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
    #screws
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 5. A date or period of its own as `value` ---
// `references.service-time(value: ..)` prints a date or a period `(start,
// end)` in the date format of the locale, as the e-invoice states it. What
// it prints is compared with the e-invoice whatever its title.
#printed-test(
  references: (
    references.service-time(value: day(6, 12)),
    references.service-time(label: "Lieferzeitraum", value: june),
  ),
  refs => {
    assert.eq(refs, (
      ("Leistungszeitraum", "12.06.2026"),
      ("Lieferzeitraum", "01.06.2026 – 30.06.2026"),
    ))
    []
  },
)[#mixed]
// The date of the dated item, as the e-invoice states it
#report-test(
  references: (references.service-time(value: day(8, 15)),),
  result => {
    assert.eq(result.model.delivery.printed, "15.08.2026")
    assert.eq(result.diagnostics.map(d => d.rule), ("IP-UNIT-01",))
  },
)[
  #line-items[
    #item([A], price: 100, date: day(8, 15))
    #screws
  ]
  #payment-goal(days: 14)
  #bank
]
// Another date contradicts the e-invoice
#report-test(
  references: (references.service-time(value: day(8, 14)),),
  result => {
    assert.eq(errors(result), ("IP-PERIOD-01",))
    assert.eq(
      result.diagnostics.first().message,
      "The invoice prints the service period \"14.08.2026\", but the e-invoice states \"15.08.2026\" (BT-72), from the dates of the items.",
    )
  },
)[
  #line-items[#item([A], price: 100, date: day(8, 15))]
  #payment-goal(days: 14)
  #bank
]
// ... also under a title of its own, and as a period besides the invoice's
// `service-period`
#report-test(
  service-period: june,
  references: (
    references.service-time(label: "Lieferzeitraum", value: (
      day(6, 1),
      day(6, 15),
    )),
  ),
  result => {
    assert.eq(result.model.delivery.printed, "01.06.2026 – 15.06.2026")
    assert.eq(errors(result), ("IP-PERIOD-01",))
    assert.eq(
      result.diagnostics.first().message,
      "The invoice prints the service period \"01.06.2026 – 15.06.2026\", but the e-invoice states \"01.06.2026 – 30.06.2026\" (BG-14).",
    )
  },
)[
  #line-items[#item([Wartung Juni], price: 100)]
  #payment-goal(days: 14)
  #bank
]
#report-test(
  service-period: june,
  references: (references.service-time(label: "Lieferzeitraum", value: june),),
  result => assert.eq(result.diagnostics.map(d => d.rule), ("IP-UNIT-01",)),
)[
  #line-items[
    #item([Wartung Juni], price: 100)
    #screws
  ]
  #payment-goal(days: 14)
  #bank
]

// A text of its own besides the invoice's `service-period`: a warning
#report-test(
  service-period: june,
  references: (references.service-time(value: [Juni 2026]),),
  result => {
    assert.eq(result.model.delivery.printed, "Juni 2026")
    assert.eq(result.model.delivery.printed-own, true)
    assert.eq(warnings(result), ("IP-PERIOD-01",))
    assert.eq(
      result.diagnostics.first().message,
      "The invoice prints the service period \"Juni 2026\" as a text of its own, but the e-invoice states \"01.06.2026 – 30.06.2026\" (BG-14). Make sure that both name the same period.",
    )
  },
)[
  #line-items[#item([Wartung Juni], price: 100)]
  #payment-goal(days: 14)
  #bank
]

// A credit note without dates states no date of the supply: a date printed
// with `value` is missing from the e-invoice (an error), a text of its own
// cannot be compared (a warning)
#report-test(
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  references: (references.service-time(value: day(8, 20)),),
  result => {
    assert.eq(result.model.delivery.text, none)
    assert.eq(errors(result), ("IP-PERIOD-01",))
    assert.eq(
      result.diagnostics.find(d => d.rule == "IP-PERIOD-01").message,
      "The invoice prints the service period \"20.08.2026\", but the e-invoice states none, as the date of a credit note is not the date of the supply.",
    )
  },
)[#undated]
#report-test(
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  references: (references.service-time(value: [August 2026]),),
  result => {
    assert.eq(errors(result), ())
    assert.eq(warnings(result), ("IP-PERIOD-01",))
    assert.eq(
      result.diagnostics.find(d => d.rule == "IP-PERIOD-01").message,
      "The invoice prints the service period \"August 2026\" as a text of its own, but the e-invoice states none, as the date of a credit note is not the date of the supply.",
    )
  },
)[#undated]

// Every report above was shown and checked.
#context assert.eq(query(<report-checked>).len(), 11)
