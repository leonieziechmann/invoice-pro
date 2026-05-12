#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
)

#data-test(test: (ctx, data) => {
  let line-items-data = loom.query.find-signal(data, "line-items")

  let expected-net = decimal("100")
  let expected-gross = decimal("119")

  assert.eq(
    line-items-data.total.net,
    expected-net,
    message: "Net total mismatch",
  )
  assert.eq(
    line-items-data.total.gross,
    expected-gross,
    message: "Gross total mismatch",
  )
})[
  #line-items[
    #item(
      [Test Item],
      price: 100.00,
      quantity: 1,
      tax: tax.vat(19%),
    )
  ]
]
