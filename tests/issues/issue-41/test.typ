// Regression test for GitHub issue #41
// https://github.com/leonieziechmann/invoice-pro/issues/41
//
// Feature request:
// For B2B invoices, customers are mostly interested in the net price. The bold
// net total ("Gesamt netto") was only rendered when a discount or surcharge was
// applied. In exclusive (net) mode it must always be shown, while the plain
// subtotal ("Summe (netto)") is only needed when modifiers change it.

#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

// Tags each rendered subtotal / net total row so the final layout can be
// queried for the rows the default totals renderer actually placed.
#let row-marker(scenario, row) = [#metadata((
  scenario: scenario,
  row: row.kind,
  emphasis: row.emphasis,
)) <issue-41-row>]

// The scenarios use minimal invoice data, so they render without validation
// feedback (`validation: none`): the feedback is not what these checks are about.
//
// The rows come from the totals row model (`view.totals.rows`): a wrap of the
// `totals` part tags the subtotal and net total labels, then hands the rows to
// the default renderer.
#let marked-invoice(scenario, tax-mode: "exclusive", body) = invoice(
  theme: theme.plain.with(theme.custom.wrap("totals", (ctx, view, inner) => {
    let tag(r) = r + (label: [#r.label#row-marker(scenario, r)])
    let rows = view.totals.rows.map(r => {
      if r.kind in ("subtotal", "net-total") { tag(r) } else { r }
    })
    inner(ctx, view + (totals: view.totals + (rows: rows)))
  })),
  locale: test-locale,
  validation: none,
  tax-mode: tax-mode,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  body,
)

// 1. Exclusive mode without modifiers: only the net total is shown
#marked-invoice("exclusive-plain")[
  #line-items[
    #item([Consulting], price: 100.00, tax: tax.vat(19%))
  ]
]

// 2. Exclusive mode with a discount: subtotal is followed by the net total
#marked-invoice("exclusive-discount")[
  #line-items[
    #item([Consulting], price: 100.00, tax: tax.vat(19%))
    #discount([Loyalty], amount: 10%)
  ]
]

// 3. Inclusive mode without modifiers: neither row is shown (unchanged)
#marked-invoice("inclusive-plain", tax-mode: "inclusive")[
  #line-items[
    #item([Consulting], price: 119.00, tax: tax.vat(19%))
  ]
]

#context {
  let placed = query(<issue-41-row>).map(m => m.value)
  let rows(scenario) = (
    placed.filter(v => v.scenario == scenario).map(v => v.row)
  )

  assert.eq(
    rows("exclusive-plain"),
    ("net-total",),
    message: "Exclusive without modifiers: expected (\"net-total\",), got "
      + repr(rows("exclusive-plain")),
  )
  assert.eq(
    rows("exclusive-discount"),
    ("subtotal", "net-total"),
    message: "Exclusive with discount: expected (\"subtotal\", \"net-total\"), got "
      + repr(rows("exclusive-discount")),
  )
  assert.eq(
    rows("inclusive-plain"),
    (),
    message: "Inclusive without modifiers: expected (), got "
      + repr(rows("inclusive-plain")),
  )

  // the net total is the bold row
  let net-emphasis = (
    placed.filter(v => v.row == "net-total").map(v => v.emphasis).dedup()
  )
  assert.eq(
    net-emphasis,
    ("strong",),
    message: "Net total emphasis: expected (\"strong\",), got "
      + repr(net-emphasis),
  )
}
