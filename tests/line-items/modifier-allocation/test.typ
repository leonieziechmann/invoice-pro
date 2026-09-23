// How absolute document and bundle modifiers are spread over VAT categories.
//
// Bugs:
// - An absolute surcharge or discount was silently dropped when the items
//   added up to 0 or less (shipping for a free sample, a handling fee on a
//   credit), at document and at bundle level.
// - On an invoice with sales at one VAT rate and credits at another, a
//   voucher was split into a larger allowance plus a charge (shares of 200%
//   and -100%), misstating the VAT.
// - A gross modifier on an invoice whose items added up to 0 was dropped.
//
// Expected: an absolute modifier is never dropped. With one VAT category it
// goes there; otherwise it is split over the categories whose total has the
// sign of the whole total, or it is pinned to a category with `tax:`. If the
// split is undefined, the invoice does not compile and says how to fix it.

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

// The VAT basis per category key.
#let bases(li) = (
  li.item-data.taxes.pairs().map(((key, tax)) => (key, tax.basis)).to-dict()
)

// The document allowances (-) and charges (+) of the XML per category key.
#let xml-entries(model) = model.allowance-charges.map(e => (
  e.key,
  if e.charge { e.amount } else { -e.amount },
))

// --- 1. Shipping for a free sample is billed ---
#check((li, model) => {
  assert.eq(li.total.net, d("5.9"), message: "Net: " + repr(li.total.net))
  assert.eq(li.total.gross, d("7.02"))
  assert.eq(xml-entries(model), (("0.19-S", d("5.9")),))
  assert.eq(model.totals.gross, d("7.02"))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Free sample], price: 0)
    #surcharge([Shipping], amount: 5.90)
  ]
]

// --- 2. A handling fee on a credit is billed ---
#check((li, model) => {
  assert.eq(li.total.net, d("-185"))
  assert.eq(xml-entries(model), (("0.19-S", d("15")),))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Returned goods], price: -200)
    #surcharge([Handling fee], amount: 15)
  ]
]

// --- 3. A discount on a credit stays an allowance ---
#check((li, model) => {
  assert.eq(li.total.net, d("-110"))
  assert.eq(xml-entries(model), (("0.19-S", d("-10")),))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Returned goods], price: -100)
    #discount([Voucher], amount: 10)
  ]
]

// --- 4. A voucher is split over the sales only, never into a charge ---
#check((li, model) => {
  assert.eq(bases(li), ("0.19-S": d("90"), "0.07-S": d("-50")))
  assert.eq(li.total.net, d("40"))
  assert.eq(xml-entries(model), (("0.19-S", d("-10")),))
  assert.eq(model.allowance-charges.filter(e => e.charge), ())
})[
  #line-items(tax: tax.vat(19%))[
    #item([Sale], price: 100)
    #item([Return], price: -50, tax: tax.vat(7%))
    #discount([Voucher], amount: 10)
  ]
]

// --- 5. A surcharge in a bundle of free items is billed ---
#check((li, model) => {
  let line = li.item-data.items.first()
  assert.eq(line.surcharge.map(m => m.absolute), (d("4"),))
  assert.eq(line.total, d("4"))
  assert.eq(model.lines.first().net, d("4"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Package])[
      #item([Free sample], price: 0)
      #surcharge([Shipping], amount: 4)
    ]
  ]
]

// --- 6. A gross surcharge on free items (net invoice) is converted ---
#check((li, model) => {
  assert.eq(li.total.net, d("5"))
  assert.eq(li.total.gross, d("5.95"))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Free sample], price: 0)
    #surcharge([Shipping], amount: 5.95, input-gross: true)
  ]
]

// --- 7. `tax:` pins a modifier to one VAT category, even a new one ---
#check((li, model) => {
  assert.eq(bases(li), ("0.07-S": d("100"), "0.19-S": d("5.9")))
  assert.eq(li.total.gross, d("114.02"))
  assert.eq(xml-entries(model), (("0.19-S", d("5.9")),))
  assert.eq(model.taxes.map(t => t.key), ("0.07-S", "0.19-S"))
})[
  #line-items(tax: tax.vat(7%))[
    #item([Book], price: 100)
    #surcharge([Shipping], amount: 5.90, tax: tax.vat(19%))
  ]
]

// --- 8. A pinned percentage applies to its category only ---
#check((li, model) => {
  assert.eq(bases(li), ("0.19-S": d("100"), "0.07-S": d("90")))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Software], price: 100)
    #item([Book], price: 100, tax: tax.vat(7%))
    #discount([Book discount], amount: 10%, tax: tax.vat(7%))
  ]
]

// --- 9. Categories adding up to 0 need `tax:` ---
#let zero-total(..modifier-args) = check(
  (li, model) => {
    assert.eq(bases(li), ("0.19-S": d("105"), "0.07-S": d("-100")))
  },
)[
  #line-items(tax: tax.vat(19%))[
    #item([Sale], price: 100)
    #item([Return], price: -100, tax: tax.vat(7%))
    #surcharge([Shipping], amount: 5, ..modifier-args)
  ]
]
#{
  let message = catch(() => zero-total())
  assert(
    message != none and message.contains("cannot be split over the VAT"),
    message: "Expected an error, got " + repr(message),
  )
  assert(message.contains("tax:"), message: message)
  [#zero-total(tax: tax.vat(19%))]
}

// --- 10. A modifier without any item needs `tax:` ---
#{
  let message = catch(() => check((li, model) => none)[
    #line-items(tax: tax.vat(19%))[
      #surcharge([Shipping], amount: 5)
    ]
  ])
  assert(
    message != none and message.contains("has no items"),
    message: "Expected an error, got " + repr(message),
  )
}

// --- 11. The modifier of an item always has the item's VAT category ---
#{
  let message = catch(() => check((li, model) => none)[
    #line-items(tax: tax.vat(19%))[
      #item(
        [Book],
        price: 100,
        tax: tax.vat(7%),
        modifier: discount([Sale], amount: 5, tax: tax.vat(19%)),
      )
    ]
  ])
  assert(
    message != none and message.contains("VAT category of the item"),
    message: "Expected an error, got " + repr(message),
  )
}

// --- 12. Several positive categories: split in proportion (unchanged) ---
#check((li, model) => {
  // 30.00 × 300 / 400 = 22.50 and 30.00 × 100 / 400 = 7.50
  assert.eq(bases(li), ("0.19-S": d("322.5"), "0.07-S": d("107.5")))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Software], price: 300)
    #item([Book], price: 100, tax: tax.vat(7%))
    #surcharge([Shipping], amount: 30)
  ]
]

// --- 13. A percentage pinned to a category without items adds nothing ---
// Bug: it added an empty VAT category (a "7%: 0.00" VAT line, and a 0.00
// line in a bundle) for a discount that is 0.
#check((li, model) => {
  assert.eq(bases(li), ("0.19-S": d("100")))
  assert.eq(li.item-data.discounts, ())
  assert.eq(model.taxes.map(t => t.key), ("0.19-S",))
})[
  #line-items(tax: tax.vat(19%))[
    #item([Software], price: 100)
    #discount([Book discount], amount: 10%, tax: tax.vat(7%))
  ]
]
#check((li, model) => {
  assert.eq(li.item-data.items.map(i => i.name), ([Package],))
  assert.eq(li.item-data.items.first().total, d("100"))
})[
  #line-items(tax: tax.vat(19%))[
    #bundle([Package])[
      #item([Software], price: 100)
      #discount([Book discount], amount: 10%, tax: tax.vat(7%))
    ]
  ]
]

// --- 14. A small business charges no VAT, not even on a pinned modifier ---
// Bug: `tax: tax.vat(19%)` on a surcharge added 19% VAT to the invoice of a
// small business (`tax-exempt-small-biz`), whose items are all without VAT.
#check(
  tax-exempt-small-biz: true,
  (li, model) => {
    assert.eq(bases(li), ("0-O": d("104.9")))
    assert.eq(li.total.gross, d("104.9"))
    assert.eq(xml-entries(model), (("0-O", d("4.9")),))
  },
)[
  #line-items[
    #item([Service], price: 100)
    #surcharge([Shipping], amount: 4.90, tax: tax.vat(19%))
  ]
]
