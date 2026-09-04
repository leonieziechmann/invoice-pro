#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  invoice-nr: "GRP-001",
)

#data-test(test: (ctx, data) => {
  let li = loom.query.find-signal(data, "line-items")
  assert.ne(li, none, message: "line-items signal not found")

  let items = li.item-data.items
  assert.eq(
    items.len(),
    8,
    message: "Expected 8 items, got " + repr(items.len()),
  )

  // Check positions
  assert.eq(
    items.at(0).pos,
    "1",
    message: "Pos 0: expected '1', got " + repr(items.at(0).pos),
  )
  assert.eq(
    items.at(1).pos,
    "2.1",
    message: "Pos 1: expected '2.1', got " + repr(items.at(1).pos),
  )
  assert.eq(
    items.at(2).pos,
    "2.2",
    message: "Pos 2: expected '2.2', got " + repr(items.at(2).pos),
  )
  assert.eq(
    items.at(3).pos,
    "2.3.1",
    message: "Pos 3: expected '2.3.1', got " + repr(items.at(3).pos),
  )
  assert.eq(
    items.at(4).pos,
    "2.3.2",
    message: "Pos 4: expected '2.3.2', got " + repr(items.at(4).pos),
  )
  assert.eq(
    items.at(5).pos,
    "2.3.3",
    message: "Pos 5: expected '2.3.3', got " + repr(items.at(5).pos),
  )
  assert.eq(
    items.at(6).pos,
    "2.3.4",
    message: "Pos 6: expected '2.3.4', got " + repr(items.at(6).pos),
  )
  assert.eq(
    items.at(7).pos,
    "3",
    message: "Pos 7: expected '3', got " + repr(items.at(7).pos),
  )

  // Context inheritance: items inside Phase 1 group should inherit tax 7%
  assert.eq(
    items.at(1).tax.rate,
    decimal("0.07"),
    message: "Expected tax 7% inherited, got " + repr(items.at(1).tax.rate),
  )
  assert.eq(
    items.at(2).tax.rate,
    decimal("0.07"),
    message: "Expected tax 7% inherited, got " + repr(items.at(2).tax.rate),
  )

  // Total checks
  assert.eq(
    li.total.net,
    decimal("1350.00"),
    message: "Net total: expected 1350.00, got " + repr(li.total.net),
  )
})[
  #line-items[
    #item([Direct Item 1], price: 100)

    #group(
      [Phase 1: Konzeption],
      description: [Gruppenbeschreibung 1],
      tax: tax.vat(7%),
    )[
      #item([Workshop], price: 200)
      #item([Analyse], price: 300)

      #group([Untergruppe Frontend])[
        #item([Wireframe 1], price: 50)
        #item([Wireframe 2], price: 50)
        #item([Wireframe 3], price: 50)
        #item([Wireframe 4], price: 100)
      ]
    ]

    #item([Direct Item 3], price: 500)
  ]
]
