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
  assert.eq(
    items.at(0).price,
    decimal("100.00"),
    message: "Item net price: expected 100.00, got " + repr(items.at(0).price),
  )
  assert.eq(
    items.at(0).total,
    decimal("100.00"),
    message: "Item net total: expected 100.00, got " + repr(items.at(0).total),
  )

  assert.eq(
    li.total.net,
    decimal("100.00"),
    message: "Net total: expected 100.00, got " + repr(li.total.net),
  )
  assert.eq(
    li.total.gross,
    decimal("119.00"),
    message: "Gross total: expected 119.00, got " + repr(li.total.gross),
  )
})[
  #line-items(tax-mode: "exclusive")[
    #item(
      [Item (Net input)],
      price: 100.00,
      quantity: 1,
      tax: tax.vat(19%),
    )
  ]
]
