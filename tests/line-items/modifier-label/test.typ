#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
  tax-mode: "exclusive",
)

#data-test(test: (ctx, data) => {
  let li = loom.query.find-signal(data, "line-items")
  assert.ne(li, none, message: "line-items signal not found")

  let items = li.item-data.items
  assert.eq(items.len(), 3, message: "Expected 3 items")

  // Item 1: default label (auto) -> should resolve to "Discount"
  let item1-disc = items.at(0).discounts
  assert.eq(item1-disc.len(), 1)
  assert.eq(
    item1-disc.at(0).label,
    "Discount",
    message: "Item 1 discount label expected 'Discount', got "
      + repr(item1-disc.at(0).label),
  )

  // Item 2: custom label "Special Deal"
  let item2-disc = items.at(1).discounts
  assert.eq(item2-disc.len(), 1)
  assert.eq(
    item2-disc.at(0).label,
    "Special Deal",
    message: "Item 2 discount label expected 'Special Deal', got "
      + repr(item2-disc.at(0).label),
  )

  // Item 3: label: none
  let item3-disc = items.at(2).discounts
  assert.eq(item3-disc.len(), 1)
  assert.eq(
    item3-disc.at(0).label,
    none,
    message: "Item 3 discount label expected none, got "
      + repr(item3-disc.at(0).label),
  )

  // Global discounts
  let global-discounts = li.item-data.discounts
  assert.eq(global-discounts.len(), 2, message: "Expected 2 global discounts")

  // Global discount 1: label "VIP Rebate"
  assert.eq(
    global-discounts.at(0).label,
    "VIP Rebate",
    message: "Global discount 1 label expected 'VIP Rebate', got "
      + repr(global-discounts.at(0).label),
  )

  // Global discount 2 via apply(label: "Scope Rebate")
  assert.eq(
    global-discounts.at(1).label,
    "Scope Rebate",
    message: "Global discount 2 label expected 'Scope Rebate', got "
      + repr(global-discounts.at(1).label),
  )
})[
  #line-items[
    // 1. Auto label
    #item(
      [Item 1],
      price: 100.00,
      modifier: discount("Summer Sale", amount: 10%),
    )

    // 2. Explicit custom label
    #item(
      [Item 2],
      price: 100.00,
      modifier: discount("Spring Sale", label: "Special Deal", amount: 10%),
    )

    // 3. Label: none
    #item(
      [Item 3],
      price: 100.00,
      modifier: discount("Cash Discount", label: none, amount: 2%),
    )

    // Global modifier with custom label
    #discount("Loyalty", label: "VIP Rebate", amount: 5%)

    // Global modifier using apply to set label
    #apply(label: "Scope Rebate")[
      #discount("Partner", amount: 10)
    ]
  ]
]
