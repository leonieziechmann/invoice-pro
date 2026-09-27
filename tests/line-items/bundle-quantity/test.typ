// Bundle modifiers with a bundle quantity above 1.
//
// Bug: a percentage modifier of a bundle was computed for one unit of the
// bundle, but applied to the whole line: a bundle of 2 × 100.00 with a 10%
// discount was billed 190.00 instead of 180.00, in the PDF and the XML.
//
// Expected: a percentage applies to the whole line (every unit of the bundle),
// like on an item; an absolute amount applies once per line, like on an item.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

// Computes an invoice and calls `test` with the line-items data (printed
// values) and the e-invoice model built from it (XML values).
#let check(test, ..args, body) = invoice(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  ..args,
  data-test(
    test: (ctx, data) => {
      let li = loom.query.find-signal(data, "line-items")
      test(li, build-model(ctx + (zugferd: "en16931"), li.item-data))
    },
    body,
  ),
)

#let d = decimal

// --- 1. Single VAT rate: 2 × 100.00 with 10% discount = 180.00 ---
#check((li, model) => {
  let line = li.item-data.items.first()
  assert.eq(line.quantity, d("2"))
  assert.eq(line.price, d("100"))
  assert.eq(
    line.discounts.map(m => m.absolute),
    (d("-20"),),
    message: "Discount: expected -20.00, got " + repr(line.discounts),
  )
  assert.eq(line.total, d("180"), message: "Line: " + repr(line.total))
  assert.eq(li.total.net, d("180"))

  let xml-line = model.lines.first()
  assert.eq(xml-line.allowances.map(a => a.amount), (d("20"),))
  assert.eq(xml-line.net, d("180"))
  assert.eq(model.totals.net, d("180"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Package], quantity: 2)[
      #item([Part A], price: 100.00)
      #discount([Package discount], amount: 10%)
    ]
  ]
]

// --- 2. Mixed VAT rates: every bracket gets 10% of its whole line ---
#check((li, model) => {
  let (book, software) = li.item-data.items
  assert.eq(book.unmodified-total, d("40"))
  assert.eq(book.discounts.map(m => m.absolute), (d("-4"),))
  assert.eq(book.total, d("36"))
  assert.eq(software.unmodified-total, d("160"))
  assert.eq(software.discounts.map(m => m.absolute), (d("-16"),))
  assert.eq(software.total, d("144"))
  assert.eq(li.total.net, d("180"))

  assert.eq(model.lines.map(l => l.net), (d("36"), d("144")))
  assert.eq(
    model.lines.map(l => l.allowances.map(a => a.amount)),
    ((d("4"),), (d("16"),)),
  )
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Starter package], quantity: 2)[
      #item([Book], price: 20, tax: tax.vat(7%))
      #item([Software], price: 80)
      #discount([Package discount], amount: 10%)
    ]
  ]
]

// --- 3. Gross prices, 3 bundles, 10% surcharge per VAT bracket ---
#check(
  tax-mode: "inclusive",
  (li, model) => {
    let (a, b) = li.item-data.items
    // 3 × 119.00 = 357.00 + 35.70; 3 × 107.00 = 321.00 + 32.10
    assert.eq(a.surcharge.map(m => m.absolute), (d("35.7"),))
    assert.eq(a.total, d("392.7"))
    assert.eq(b.surcharge.map(m => m.absolute), (d("32.1"),))
    assert.eq(b.total, d("353.1"))
    assert.eq(li.total.gross, d("745.8"))
    // Net: 330.00 per bracket
    assert.eq(model.lines.map(l => l.net), (d("330"), d("330")))
    assert.eq(model.totals.gross, d("745.8"))
  },
)[
  #line-items[
    #bundle([Package], quantity: 3)[
      #item([Part A], price: 119.00, tax: tax.vat(19%))
      #item([Part B], price: 107.00, tax: tax.vat(7%))
      #surcharge([Express], amount: 10%)
    ]
  ]
]

// --- 4. An absolute bundle modifier applies once per line ---
#check((li, model) => {
  let line = li.item-data.items.first()
  assert.eq(line.discounts.map(m => m.absolute), (d("-5"),))
  assert.eq(line.total, d("195"))
  assert.eq(model.lines.first().net, d("195"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Package], quantity: 2)[
      #item([Part A], price: 100.00)
      #discount([Voucher], amount: 5)
    ]
  ]
]

// --- 5. A price per base quantity: 250 units at 4.00 per 100, 10% off ---
#check((li, model) => {
  let line = li.item-data.items.first()
  assert.eq(line.unmodified-total, d("10"))
  assert.eq(line.discounts.map(m => m.absolute), (d("-1"),))
  assert.eq(line.total, d("9"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Screws], quantity: 250, base-quantity: 100)[
      #item([Screw], price: 4.00)
      #discount([Bulk discount], amount: 10%)
    ]
  ]
]
