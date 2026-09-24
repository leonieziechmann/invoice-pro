// The preceding invoice reference (BG-3): its number (BT-25) and date
// (BT-26), a date without number (BR-55), and the corrected invoice, which
// must name the invoice it replaces (BR-DE-26 in XRechnung, IP-DOC-02).

#import "/src/lib.typ": *
#import "/src/utils/text.typ": plain-text
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
)

#let preceding-date = datetime(year: 2026, month: 8, day: 30)

// --- 1. Number and date are written as BG-3 ---
#model-test(
  preceding-invoice-nr: "R-2026-11",
  preceding-invoice-date: preceding-date,
  model => {
    assert.eq(model.invoice.preceding-invoice-date, preceding-date)
    let expected = (
      "<ram:InvoiceReferencedDocument><ram:IssuerAssignedID>R-2026-11</ram:IssuerAssignedID><ram:FormattedIssueDateTime><qdt:DateTimeString format=\"102\">20260830</qdt:DateTimeString></ram:FormattedIssueDateTime></ram:InvoiceReferencedDocument>",
    )
    assert.eq(xml-elements(model, "ram:InvoiceReferencedDocument"), expected)
    assert.eq(rules(model), ())
    // BASIC WL carries the reference as well, MINIMUM does not
    let m = model
    m.profile = resolve-profile("basic-wl", "FR")
    assert.eq(xml-elements(m, "ram:InvoiceReferencedDocument"), expected)
    m.profile = resolve-profile("minimum", "FR")
    assert.eq(xml-elements(m, "ram:InvoiceReferencedDocument"), ())
    assert.eq(rules(m), ())
    // ... which is reported as a warning
    assert.eq(rules(m, level: "warning"), ("IP-PROFILE-01",))
    let d = diagnostic(m, "IP-PROFILE-01")
    assert.eq(d.field, "preceding-invoice-nr")
    assert.eq(
      d.message,
      "The MINIMUM profile cannot state the preceding invoice reference (BG-3), so `preceding-invoice-nr` and `preceding-invoice-date` are not written into the e-invoice.",
    )
  },
)[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// Without a date, only the number
#model-test(preceding-invoice-nr: "R-2026-11", model => {
  assert.eq(xml-elements(model, "ram:InvoiceReferencedDocument"), (
    "<ram:InvoiceReferencedDocument><ram:IssuerAssignedID>R-2026-11</ram:IssuerAssignedID></ram:InvoiceReferencedDocument>",
  ))
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 2. A date without number cannot be written (BR-55) ---
#model-test(preceding-invoice-date: preceding-date, model => {
  assert.eq(rules(model), ("BR-55",))
  let d = diagnostic(model, "BR-55")
  assert.eq(d.field, "preceding-invoice-nr")
  assert.eq(d.hint, "Set `preceding-invoice-nr` on the invoice.")
  assert.eq(xml-elements(model, "ram:InvoiceReferencedDocument"), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 3. A corrected invoice names the invoice it replaces ---
#model-test(document-type: "corrected", model => {
  assert.eq(rules(model), ("IP-DOC-02",))
  assert.eq(
    diagnostic(model, "IP-DOC-02").message,
    "A corrected invoice (BT-3 = 384) replaces a preceding invoice, but it names none (BG-3).",
  )
  // XRechnung checks it as BR-DE-26
  let m = model
  m.profile = resolve-profile("xrechnung", "DE")
  assert("BR-DE-26" in rules(m))
  assert("IP-DOC-02" not in rules(m))
  // MINIMUM has no preceding invoice reference
  m.profile = resolve-profile("minimum", "FR")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

#model-test(
  document-type: "corrected",
  preceding-invoice-nr: "R-2026-11",
  preceding-invoice-date: preceding-date,
  model => assert.eq(rules(model), ()),
)[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 4. The printed reference ---
#invoice(
  theme: () => (
    themes.blank()
      + (
        document: (ctx, body) => {
          assert.eq(ctx.references, (
            ("Vorherige Rechnungsnummer", "R-2026-11"),
            ("Datum der vorherigen Rechnung", "30.08.2026"),
          ))
          []
        },
      )
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-de,
  preceding-invoice-nr: "R-2026-11",
  preceding-invoice-date: preceding-date,
  references: (
    references.preceding-invoice-nr,
    references.preceding-invoice-date(),
  ),
)[]

// The default references print the preceding invoice the e-invoice states,
// e.g. the invoice a credit note refers to
#let default-references(check, ..args) = invoice(
  theme: () => (
    themes.blank()
      + (
        document: (ctx, body) => {
          check(ctx.references)
          []
        },
      )
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-de,
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
)[]
// The date of the supply of a German seller (§ 14 Abs. 4 Satz 1 Nr. 6
// UStG), here the invoice date, is marked content
#let plain-refs(refs) = refs.map(((label, value)) => (label, plain-text(value)))
// A credit note amends the preceding invoice: its own date (01.09.2026) is
// not the date of the supply, so without dates it prints none
#default-references(
  document-type: "credit-note",
  preceding-invoice-nr: "R-2026-11",
  preceding-invoice-date: preceding-date,
  refs => assert.eq(plain-refs(refs), (
    ("Steuernummer", "123/456/78901"),
    ("USt-IdNr.", "DE123456789"),
    ("Empfänger:in USt-IdNr.", "DE987654321"),
    ("Vorherige Rechnungsnummer", "R-2026-11"),
    ("Datum der vorherigen Rechnung", "30.08.2026"),
  )),
)
// ... but its `service-period`
#default-references(
  document-type: "credit-note",
  preceding-invoice-nr: "R-2026-11",
  service-period: datetime(year: 2026, month: 8, day: 20),
  refs => assert.eq(plain-refs(refs).slice(3), (
    ("Leistungszeitraum", "20.08.2026"),
    ("Vorherige Rechnungsnummer", "R-2026-11"),
  )),
)
// A corrected invoice replaces the preceding invoice, with all of its
// details: the invoice date, as for any invoice
#default-references(
  document-type: "corrected",
  preceding-invoice-nr: "R-2026-11",
  refs => assert.eq(plain-refs(refs).slice(3), (
    ("Leistungszeitraum", "01.09.2026"),
    ("Vorherige Rechnungsnummer", "R-2026-11"),
  )),
)
// With gross prices (B2C) as well
#default-references(
  tax-mode: "inclusive",
  preceding-invoice-nr: "R-2026-11",
  refs => assert.eq(plain-refs(refs).slice(3), (
    ("Leistungszeitraum", "01.09.2026"),
    ("Vorherige Rechnungsnummer", "R-2026-11"),
  )),
)
