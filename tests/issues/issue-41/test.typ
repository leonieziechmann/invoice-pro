// Regression test for GitHub issue #41
// https://github.com/leonieziechmann/invoice-pro/issues/41
//
// Feature request:
// For B2B invoices, customers are mostly interested in the net price. The bold
// net total ("Gesamt netto") was only rendered when a discount or surcharge was
// applied. In exclusive (net) mode it must always be shown, while the plain
// subtotal ("Summe (netto)") is only needed when modifiers change it.

#import "/src/lib.typ": *
#import "/src/themes/components/line-items/line-items.typ": (
  render-line-items as generic-render-line-items,
)
#import "/src/themes/components/line-items/totals.typ"
#import "/tests/test-locale.typ": test-locale

// Tags each rendered subtotal / net total row so the final layout can be
// queried for the rows the default totals body actually placed.
#let row-marker(scenario, row) = [#metadata((
  scenario: scenario,
  row: row,
)) <issue-41-row>]

#let marked-invoice(scenario, tax-mode: "exclusive", body) = invoice(
  theme: themes.blank.with(
    line-items: generic-render-line-items.with(
      render-subtotal: (ctx, value, styles) => {
        let (label, val) = totals.default-render-subtotal(ctx, value, styles)
        ([#label#row-marker(scenario, "subtotal")], val)
      },
      render-total-net: (ctx, value, styles) => {
        let (label, val) = totals.default-render-total-net(ctx, value, styles)
        ([#label#row-marker(scenario, "net-total")], val)
      },
    ),
  ),
  locale: test-locale,
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
  let rows(scenario) = (
    query(<issue-41-row>)
      .map(m => m.value)
      .filter(v => v.scenario == scenario)
      .map(v => v.row)
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
}
