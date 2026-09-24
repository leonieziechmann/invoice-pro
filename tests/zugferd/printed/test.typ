// The printed invoice shows what the law requires on an invoice and the
// e-invoice states: the seller's tax number or VAT ID (IP-PRINT-03) and the
// date of the supply (IP-PERIOD-03). Invoice-pro knows what a theme prints
// only if the theme says so (`prints`): the DIN 5008 letter prints the
// reference signs and the `extra` of the parties, and a footer of its own
// whose text invoice-pro cannot read. The blank theme prints neither, so
// nothing is checked there.

#import "/src/lib.typ": *
#import "/tests/zugferd/harness.typ": bank, buyer-de, seller

#let day(month, day) = datetime(year: 2026, month: month, day: day)
#let din = themes.DIN-5008(font: "libertinus serif")

// Renders an EN 16931 invoice between German parties with `theme` (the DIN
// 5008 letter by default) and hands the diagnostics of the e-invoice to
// `check`, as `(rule, level)` pairs, without the warning about the unit
// "STK" (IP-UNIT-01) of every invoice here, which shows the report. Each
// shown report leaves a marker, which the end of the file counts.
#let report-test(check, theme: din, ..args, body) = invoice(
  theme: () => (
    theme()
      + (
        zugferd-report: (ctx, result) => {
          let diagnostics = result.diagnostics.filter(d => (
            d.rule != "IP-UNIT-01"
          ))
          check(diagnostics.map(d => (d.rule, d.level)).sorted(), diagnostics)
          [#metadata(none)<report-checked>]
        },
      )
  ),
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "report",
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "2026-01",
  date: day(9, 1),
  ..args,
  body,
)

// Items above the amount of a small-amount invoice (250 euros), the last
// with a unit only EN 16931 knows.
#let items(..dates) = [
  #line-items[
    #item([Wartung], price: 1000, ..dates)
    #item([Schrauben], price: 1, quantity: 10, unit: "STK")
  ]
  #payment-goal(days: 14)
  #bank
]
// ... and below it (130.90 euros)
#let small-items = [
  #line-items[
    #item([Wartung], price: 100)
    #item([Schrauben], price: 1, quantity: 10, unit: "STK")
  ]
  #payment-goal(days: 14)
  #bank
]

// Reference signs without the seller's tax identifiers and the date of the
// supply. The invoice date (01.09.2026) is the date of the supply the
// e-invoice states, but printed as the invoice date, it does not state it.
#let signs = (references.invoice-nr(), references.invoice-date())

// --- 1. Neither printed: errors ---
#report-test(references: signs, (rules, diagnostics) => {
  assert.eq(rules, (("IP-PERIOD-03", "error"), ("IP-PRINT-03", "error")))
  let find(rule) = diagnostics.find(d => d.rule == rule)
  assert.eq(find("IP-PRINT-03").field, "references")
  assert.eq(
    find("IP-PRINT-03").message,
    "The e-invoice states the seller's VAT identifier \"DE123456789\" (BT-31) and tax number \"123/456/78901\" (BT-32), but the printed invoice shows neither. The printed invoice and the e-invoice must state the same details, and the law requires the seller's tax number or VAT identifier on every invoice but a small-amount invoice (§ 14 Abs. 4 Satz 1 Nr. 2 UStG, § 33 UStDV; Art. 226 No. 3 of the VAT Directive).",
  )
  assert(find("IP-PRINT-03").hint.contains("`references.seller-vat-id()`"))
  assert.eq(find("IP-PERIOD-03").field, "references")
  assert.eq(
    find("IP-PERIOD-03").message,
    "The printed invoice does not show the date of the supply (\"01.09.2026\" in the e-invoice, BT-72), which German law requires on the invoice, also when it is the date of the invoice (§ 14 Abs. 4 Satz 1 Nr. 6 UStG).",
  )
})[#items()]
// Only the VAT ID stated: "it nowhere"
#report-test(
  references: signs + (references.service-time(),),
  sender: seller + (tax-nr: none),
  (rules, diagnostics) => {
    assert.eq(rules, (("IP-PRINT-03", "error"),))
    assert(
      diagnostics
        .first()
        .message
        .starts-with(
          "The e-invoice states the seller's VAT identifier \"DE123456789\" (BT-31), but the printed invoice shows it nowhere.",
        ),
    )
  },
)[#items()]

// --- 2. The default references and every preset print both ---
#report-test(references: auto, (rules, _) => assert.eq(rules, ()))[#items()]
#for preset in (
  references.preset-b2b,
  references.preset-b2g,
  references.preset-project,
  references.preset-din-5008,
) {
  report-test(references: preset(), (rules, _) => assert.eq(rules, ()))[
    #items()
  ]
}

// --- 3. The seller's tax number or VAT ID anywhere on the page ---
// The tax number alone
#report-test(
  references: signs + (references.seller-tax-nr(), references.service-time()),
  (rules, _) => assert.eq(rules, ()),
)[#items()]
// In the `extra` of the sender, with spaces
#report-test(
  references: signs + (references.service-time(),),
  sender: seller + (extra: (("USt-IdNr.", "DE 123 456 789"),)),
  (rules, _) => assert.eq(rules, ()),
)[#items()]
// In the text of the invoice
#report-test(
  references: signs + (references.service-time(),),
  (rules, _) => assert.eq(rules, ()),
)[
  #items()
  Steuernummer: #info.sender.tax-nr
]
// A footer of the theme may show it: not known
#report-test(
  theme: themes.DIN-5008(font: "libertinus serif", footer: [Seller GmbH]),
  references: signs,
  (rules, _) => assert.eq(rules, (("IP-PERIOD-03", "error"),)),
)[#items()]
// The blank theme prints no references: not known
#report-test(
  theme: themes.blank,
  references: signs,
  (rules, _) => assert.eq(rules, ()),
)[#items()]

// --- 4. The date of the supply anywhere on the page ---
// With the items: the date of the item is printed
#report-test(
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, ()),
)[#items(date: day(8, 15))]
// ... below the items without the date column, if all have one date ...
#let dated(..args) = [
  #line-items(show-column: (date: false), ..args)[
    #item([Wartung], price: 1000, date: day(8, 15))
    #item([Schrauben], price: 1, quantity: 10, unit: "STK", date: day(8, 15))
  ]
  #payment-goal(days: 14)
  #bank
]
#report-test(
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, ()),
)[#dated()]
// ... but not with `show-information: false`
#report-test(
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, (("IP-PERIOD-03", "error"),)),
)[#dated(show-information: false)]
// In a reference of another title
#report-test(
  references: signs
    + (references.seller-vat-id(), ("Lieferdatum", "01.09.2026")),
  (rules, _) => assert.eq(rules, ()),
)[#items()]
// In the text of the invoice
#report-test(
  references: signs + (references.seller-vat-id(),),
  service-period: (day(8, 1), day(8, 31)),
  (rules, _) => assert.eq(rules, ()),
)[
  #items()
  Leistungszeitraum: 01.08.2026 - 31.08.2026
]
// Another date in the text is not the date of the supply
#report-test(
  references: signs + (references.seller-vat-id(),),
  service-period: (day(8, 1), day(8, 31)),
  (rules, diagnostics) => {
    assert.eq(rules, (("IP-PERIOD-03", "error"),))
    assert(
      diagnostics
        .first()
        .message
        .contains(
          "(\"01.08.2026 – 31.08.2026\" in the e-invoice, BG-14)",
        ),
    )
  },
)[
  #items()
  Leistungszeitraum: 01.07.2026 - 31.07.2026
]

// --- 5. Where the law does not require the date of the supply ---
// A small-amount invoice from Germany (§ 33 UStDV): a warning if it differs
// from the invoice date, which the XML states then ...
#report-test(
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, ()),
)[#small-items]
#report-test(
  references: signs + (references.seller-vat-id(),),
  service-period: (day(8, 1), day(8, 31)),
  (rules, diagnostics) => {
    assert.eq(rules, (("IP-PERIOD-03", "warning"),))
    assert.eq(
      diagnostics.first().message,
      "The e-invoice states the date of the supply \"01.08.2026 – 31.08.2026\" (BG-14), which is not the date of the invoice, but the printed invoice does not show it (a small-amount invoice of at most 250 euros need not show it, § 33 UStDV).",
    )
  },
)[#small-items]
// ... but not for a reverse charge (§ 33 Satz 3 UStDV)
#report-test(
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, (("IP-PERIOD-03", "error"),)),
)[
  #line-items[
    #item([Bauleistung], price: 100, tax: tax.reverse-charge())
    #item(
      [Schrauben],
      price: 1,
      quantity: 10,
      unit: "STK",
      tax: tax.reverse-charge(),
    )
  ]
  #payment-goal(days: 14)
  #bank
]
// A seller outside Germany: a warning if the date of the supply is not the
// invoice date (Art. 226 No. 7 of the VAT Directive)
#let seller-at = seller + (country: country.at, vat-id: "ATU12345675")
#report-test(
  sender: seller-at,
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, ()),
)[#items()]
#report-test(
  sender: seller-at,
  references: signs + (references.seller-vat-id(),),
  service-period: (day(8, 1), day(8, 31)),
  (rules, diagnostics) => {
    assert.eq(rules, (("IP-PERIOD-03", "warning"),))
    assert(
      diagnostics
        .first()
        .message
        .ends-with(
          "but the printed invoice does not show it (Art. 226 No. 7 of the VAT Directive).",
        ),
    )
  },
)[#items()]
// A credit note amends an invoice that states it
#report-test(
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  references: signs + (references.seller-vat-id(),),
  (rules, _) => assert.eq(rules, ()),
)[#items()]

// --- 6. A self-billed invoice: the seller is the recipient ---
#report-test(
  document-type: "self-billed",
  sender: buyer-de,
  recipient: seller,
  references: signs + (references.service-time(),),
  (rules, diagnostics) => {
    assert.eq(rules, (("IP-PRINT-03", "error"),))
    assert(diagnostics.first().message.contains("\"DE123456789\" (BT-31)"))
  },
)[#items()]
#report-test(
  document-type: "self-billed",
  sender: buyer-de,
  recipient: seller,
  references: auto,
  (rules, _) => assert.eq(rules, ()),
)[#items()]
#report-test(
  document-type: "self-billed",
  sender: buyer-de,
  recipient: seller + (extra: ("Steuernummer": "123/456/78901")),
  references: signs + (references.service-time(),),
  (rules, _) => assert.eq(rules, ()),
)[#items()]

// Every report above was shown and checked.
#context assert.eq(query(<report-checked>).len(), 27)
