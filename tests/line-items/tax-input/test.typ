// Tax inputs: `tax: none`, `tax.new`, hand-built tax dictionaries and the
// Swiss rates.
//
// Bugs:
// - `tax: none` silently became the zero rated category Z, although "no tax"
//   does not say which 0% category applies (the regions reject a raw 0%).
// - The documented `tax.new` was not exported, and a hand-built dictionary
//   with a ratio rate (the documented type) crashed.
// - The Swiss locale accepted the obsolete 2.5% and rejected 3.8%.
//
// Expected: `tax: none` is still printed as 0%, but marked `implicit` so that
// e-invoices can reject it; `tax.new` and hand-built dictionaries work like
// the constructors; `de-ch` knows 8.1%, 2.6% and 3.8%.

#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#let check(test, locale: test-locale, ..args, body) = invoice(
  theme: themes.blank,
  locale: locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  ..args,
  data-test(
    test: (ctx, data) => test(loom.query.find-signal(data, "line-items")),
    body,
  ),
)

#let d = decimal

// --- 1. `tax: none` is zero rated, but marked as implicit ---
#check(
  tax: none,
  li => {
    let item = li.item-data.items.first()
    assert.eq(item.tax.category, "Z")
    assert.eq(item.tax.at("implicit", default: false), true)
    let tax = li.item-data.taxes.at("0-Z")
    assert.eq(tax.implicit, true)
    assert.eq(li.total.gross, d("200"))
  },
)[
  #line-items[
    #item([Service], price: 200)
  ]
]

// An explicit `tax.zero()` is not implicit.
#check(li => {
  assert.eq(
    li.item-data.items.first().tax.at("implicit", default: false),
    false,
  )
  assert.eq(li.item-data.taxes.at("0-Z").implicit, false)
})[
  #line-items[
    #item([Solar panel], price: 200, tax: tax.zero())
  ]
]

// --- 2. `tax.new` is exported ---
#{
  let custom = tax.new(
    rate: 0%,
    category: "E",
    label: "custom-exemption",
    grounds: "Exempt based on local regulation paragraph 42.",
  )
  assert.eq(custom.rate, d("0"))
  assert.eq(custom.category, "E")
  check(li => {
    let exempt = li.item-data.taxes.at("0-E")
    assert.eq(
      exempt.grounds,
      "Exempt based on local regulation paragraph 42.",
    )
  })[
    #line-items[
      #item([Seminar], price: 300, tax: custom)
    ]
  ]
}

// --- 3. A hand-built dictionary with a ratio rate is normalized ---
#check(li => {
  let item = li.item-data.items.first()
  assert.eq(item.tax.rate, d("0.19"))
  assert.eq(li.item-data.taxes.keys(), ("0.19-S",))
  assert.eq(li.total.gross, d("238"))
})[
  #line-items[
    #item(
      [Service],
      price: 100,
      quantity: 2,
      tax: (rate: 19%, category: "S", label: "vat", grounds: none),
    )
  ]
]

// ... also as the default tax of the invoice.
#check(
  tax: (rate: 7%, category: "S", label: "vat", grounds: none),
  li => {
    assert.eq(li.item-data.taxes.keys(), ("0.07-S",))
    assert.eq(li.total.gross, d("107"))
  },
)[
  #line-items[
    #item([Book], price: 100)
  ]
]

// --- 4. The Swiss VAT rates since 2024 ---
#check(
  locale: locale.de-ch,
  li => {
    assert.eq(
      li.item-data.taxes.keys(),
      ("0.081-S", "0.026-S", "0.038-S"),
    )
  },
)[
  #line-items[
    #item([Service], price: 100, tax: 8.1%)
    #item([Food], price: 100, tax: 2.6%)
    #item([Hotel night], price: 100, tax: 3.8%)
  ]
]
#{
  let message = catch(() => check(locale: locale.de-ch, li => none)[
    #line-items[
      #item([Hotel night], price: 100, tax: 2.5%)
    ]
  ])
  assert(
    message != none and message.contains("8.1%, 2.6%, and 3.8%"),
    message: "Expected an error for 2.5%, got " + repr(message),
  )
}
