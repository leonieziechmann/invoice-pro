// Nested bundles.
//
// Bug: the virtual item of an inner bundle was counted twice: once inside the
// outer bundle and once as a line of its own (150.00 + 100.00 = 250.00 net
// instead of 150.00, in the PDF and the XML). A nested bundle without its own
// quantity also inherited the quantity of the enclosing bundle.
//
// Expected: a nested bundle is part of the enclosing bundle's line only, and
// its quantity (default 1) is the number of it in one enclosing bundle.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

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

// --- 1. A plain nested bundle is one line of 150.00 ---
#check((li, model) => {
  let items = li.item-data.items
  assert.eq(
    items.map(i => i.name),
    ([Outer],),
    message: "Lines: " + repr(items.map(i => i.name)),
  )
  assert.eq(items.first().total, d("150"))
  assert.eq(li.total.net, d("150"))
  assert.eq(li.total.gross, d("178.5"))
  assert.eq(model.lines.len(), 1)
  assert.eq(model.totals.net, d("150"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Outer])[
      #item([Part X], price: 50.00)
      #bundle([Inner])[
        #item([Part A], price: 100.00)
      ]
    ]
  ]
]

// --- 2. Quantities: 3 × (2 × 100.00 - 10%) = 540.00 ---
#check((li, model) => {
  let items = li.item-data.items
  assert.eq(items.len(), 1)
  let outer = items.first()
  assert.eq(outer.quantity, d("3"))
  assert.eq(outer.price, d("180"))
  assert.eq(outer.total, d("540"))
  assert.eq(li.total.net, d("540"))
  assert.eq(model.totals.net, d("540"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Outer], quantity: 3)[
      #bundle([Inner], quantity: 2)[
        #item([Part A], price: 100.00)
        #discount([Inner discount], amount: 10%)
      ]
    ]
  ]
]

// --- 3. A nested bundle without a quantity counts once per outer bundle ---
#check((li, model) => {
  let items = li.item-data.items
  assert.eq(items.len(), 1)
  // 3 × (50.00 + 1 × 100.00)
  assert.eq(items.first().total, d("450"))
  assert.eq(li.total.net, d("450"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Outer], quantity: 3)[
      #item([Part X], price: 50.00)
      #bundle([Inner])[
        #item([Part A], price: 100.00)
      ]
    ]
  ]
]

// --- 4. Nested bundles with mixed VAT rates next to a plain item ---
#check((li, model) => {
  let items = li.item-data.items
  assert.eq(items.len(), 3)
  assert.eq(items.map(i => i.total), (d("20"), d("60"), d("80")))
  assert.eq(li.total.net, d("160"))
  assert.eq(model.lines.map(l => l.net), (d("20"), d("60"), d("80")))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Single], price: 20.00)
    #bundle([Outer])[
      #item([Book], price: 10.00, tax: tax.vat(7%))
      #bundle([Inner])[
        #item([Book 2], price: 50.00, tax: tax.vat(7%))
        #item([Software], price: 80.00)
      ]
    ]
  ]
]
