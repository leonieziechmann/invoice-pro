#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
  tax-mode: "inclusive",
)

#data-test(test: (ctx, data) => {
  let li = loom.query.find-signal(data, "line-items")
  assert.ne(li, none, message: "line-items signal not found")

  let items = li.item-data.items

  // Item A: price: 119.00, qty: 1, tax: 19% -> auto input-gross: true -> gross 119.00
  assert.eq(
    items.at(0).price,
    decimal("119.00"),
    message: "Item A gross price: expected 119.00, got "
      + repr(items.at(0).price),
  )
  assert.eq(
    items.at(0).total,
    decimal("119.00"),
    message: "Item A gross total: expected 119.00, got "
      + repr(items.at(0).total),
  )

  // Item B: price: 100.00, qty: 1, tax: 19%, input-gross: false -> net 100.00 -> gross 119.00
  assert.eq(
    items.at(1).price,
    decimal("119.00"),
    message: "Item B gross price: expected 119.00, got "
      + repr(items.at(1).price),
  )
  assert.eq(
    items.at(1).total,
    decimal("119.00"),
    message: "Item B gross total: expected 119.00, got "
      + repr(items.at(1).total),
  )

  // Bundle virtual item: price: 59.50, qty: 1, tax: 19% -> auto input-gross: true -> gross 59.50
  assert.eq(
    items.at(2).price,
    decimal("59.50"),
    message: "Bundle gross price: expected 59.50, got "
      + repr(items.at(2).price),
  )
  assert.eq(
    items.at(2).total,
    decimal("59.50"),
    message: "Bundle gross total: expected 59.50, got "
      + repr(items.at(2).total),
  )

  // Net total: 100.00 + 100.00 + 50.00 - 10.00 = 240.00
  assert.eq(
    li.total.net,
    decimal("240.00"),
    message: "Net total: expected 240.00, got " + repr(li.total.net),
  )

  // Gross total: 119.00 + 119.00 + 59.50 - 11.90 = 285.60
  assert.eq(
    li.total.gross,
    decimal("285.60"),
    message: "Gross total: expected 285.60, got " + repr(li.total.gross),
  )

  // Tax total: 285.60 - 240.00 = 45.60
  let tax-entry = li.item-data.taxes.values().first()
  assert.eq(
    tax-entry.absolute,
    decimal("45.60"),
    message: "Tax total: expected 45.60, got " + repr(tax-entry.absolute),
  )
})[
  #line-items[
    // Item A inherits input-gross: true from tax-mode: "inclusive"
    #item(
      [Item A (Gross input)],
      price: 119.00,
      quantity: 1,
      tax: tax.vat(19%),
    )

    // Item B overrides to input-gross: false (Net input)
    #item(
      [Item B (Net input)],
      price: 100.00,
      quantity: 1,
      tax: tax.vat(19%),
      input-gross: false,
    )

    // Bundle inherits input-gross: true
    #bundle([Bundle C], quantity: 1)[
      #item(
        [Subitem in Bundle],
        price: 59.50,
        quantity: 1,
        tax: tax.vat(19%),
      )
    ]

    // Modifier inherits input-gross: true
    #discount([Volume Discount], amount: 11.90)
  ]
]
