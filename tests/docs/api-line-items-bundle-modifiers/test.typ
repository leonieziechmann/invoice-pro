// Source: docs/docs/api-reference/line-items/index.md — "Quantities and
// Modifiers of a Bundle" and "VAT Categories of Document and Bundle Modifiers"
#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom

#let example(test, body) = invoice(
  theme: themes.DIN-5008(font: "libertinus serif"),
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  data-test(
    test: (ctx, data) => test(loom.query.find-signal(data, "line-items")),
    body,
  ),
)

// Nested bundles
#example(li => assert.eq(li.total.net, decimal("540")))[
  #line-items[
    #bundle([Office kit], quantity: 3)[
      // 3 × (2 × 100.00 − 10%) = 540.00
      #bundle([Chair set], quantity: 2)[
        #item([Chair], price: 100.00)
        #discount([Set discount], amount: 10%)
      ]
    ]
  ]
]

// Shipping at 19% on an invoice of books at 7%
#example(li => {
  let bases = li.item-data.taxes.values().map(t => (t.rate, t.basis))
  assert.eq(bases, (
    (decimal("0.07"), decimal("25")),
    (decimal("0.19"), decimal("4.9")),
  ))
})[
  #line-items[
    #item([Book], price: 25.00, tax: tax.vat(7%))
    #surcharge([Shipping], amount: 4.90, tax: tax.vat(19%))
  ]
]
