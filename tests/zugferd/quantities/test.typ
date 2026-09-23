// A quantity (BT-129) and a price base quantity (BT-149) are rounded to 4
// decimals once, before anything is calculated with them: the line total,
// the printed quantity and the e-invoice use the same value, e.g. 0.3333 for
// a third.

#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/zugferd/harness.typ": bank, model-test, rules, xml-values

// --- 1. A third of an hour: 1000 x 0.3333 = 333.30, as printed and written,
// not 333.33 from a quantity the invoice never shows ---
#model-test(model => {
  let lines = model.lines
  assert.eq(lines.map(l => l.quantity), (
    decimal("0.3333"),
    decimal("0.125"),
    decimal("0.1235"),
  ))
  assert.eq(lines.map(l => l.net), (
    decimal("333.30"),
    decimal("12.50"),
    decimal("12.35"),
  ))
  assert.eq(xml-values(model, "ram:BilledQuantity"), (
    "0.3333",
    "0.125",
    "0.1235",
  ))
  assert.eq(rules(model), ())
})[
  #line-items[
    #item([Beratung], price: 1000, quantity: 1 / 3, unit: unit.hour)
    #item([Wartung], price: 100, quantity: 0.125, unit: unit.hour)
    #item([Strom], price: 100, quantity: 0.12345, unit: "kWh")
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 2. The price base quantity, too ---
#model-test(model => {
  let line = model.lines.first()
  assert.eq(line.base-quantity, decimal("0.3333"))
  assert.eq(xml-values(model, "ram:BasisQuantity"), ("0.3333",))
  // 10 / 0.3333 x 30 = 900.09
  assert.eq(line.net, decimal("900.09"))
})[
  #line-items[
    #item([Kies], price: 30, quantity: 10, base-quantity: 1 / 3)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 3. The quantity of a bundle ---
#model-test(model => {
  let line = model.lines.first()
  assert.eq(line.quantity, decimal("0.6667"))
  // 0.6667 x 1500 = 1000.05
  assert.eq(line.net, decimal("1000.05"))
  assert.eq(xml-values(model, "ram:BilledQuantity"), ("0.6667",))
  assert.eq(rules(model), ())
})[
  #line-items[
    #bundle([Paket], quantity: 2 / 3)[
      #item([A], price: 1000)
      #item([B], price: 500)
    ]
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 4. The printed quantity is the one the total is calculated with ---
#invoice(
  theme: themes.blank,
  locale: locale.de-de,
  sender: (name: "Seller", address: "Street 1", city: "12345 City"),
  recipient: (name: "Buyer", address: "Street 2", city: "12345 City"),
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  data-test(
    test: (ctx, data) => {
      let line-items = loom.query.find-signal(data, "line-items")
      let item = line-items.item-data.items.first()
      assert.eq(item.quantity, decimal("0.3333"))
      assert.eq((ctx.locale.format.number)(item.quantity), "0,3333")
      assert.eq(item.total, decimal("333.30"))
    },
    line-items[#item([Beratung], price: 1000, quantity: 1 / 3)],
  ),
)

// --- 5. A base quantity that is 0 once rounded is an error, not a division
// by 0 ---
#for (component, value, body) in (
  ("item", "0.00001", () => item([Kies], price: 30, base-quantity: 0.00001)),
  (
    "bundle",
    "0.00004",
    () => bundle([Paket], base-quantity: 0.00004)[
      #item([A])
    ],
  ),
) {
  let message = catch(body)
  let expected = (
    component
      + "::base-quantity must be at least 0.0001, got "
      + value
      + ". Quantities are rounded to 4 decimals."
  )
  assert(
    message != none and message.contains(expected),
    message: "Expected `" + expected + "`, got " + repr(message),
  )
}
