// Unit prices (BT-146) and their base quantity (BT-149): the net price of a
// gross price is rounded as the invoice rounds unit prices, and the base
// quantity is above 0.

#import "/src/lib.typ": *
#import "/tests/zugferd/harness.typ": bank, model-test, rules, xml-values

// --- 1. Gross prices: the net price keeps the decimals of the locale's fine
// money rounding (6 here), as the calculation does ---
#model-test(
  locale: locale.de-de.with(locale.custom.normalize(
    money-fine: x => calc.round(x, digits: 6),
  )),
  tax-mode: "inclusive",
  model => {
    // 0.123456 / 1.19 = 0.10374453...
    assert.eq(model.lines.first().price, decimal("0.103745"))
    assert.eq(xml-values(model, "ram:ChargeAmount"), ("0.103745",))
    assert.eq(rules(model), ())
  },
)[
  #line-items[#item([Strom], price: 0.123456, quantity: 10000, unit: "kWh")]
  #payment-goal(days: 14)
  #bank
]

// The default fine rounding of 4 decimals
#model-test(tax-mode: "inclusive", model => {
  assert.eq(model.lines.first().price, decimal("0.1038"))
})[
  #line-items[#item([Strom], price: 0.1235, quantity: 10000, unit: "kWh")]
  #payment-goal(days: 14)
  #bank
]

// --- 2. The price base quantity is above 0 (PEPPOL-EN16931-R121) ---
#model-test(model => {
  let m = model
  m.lines.at(0).base-quantity = decimal("0")
  assert.eq(rules(m), ("PEPPOL-EN16931-R121",))
  m.lines.at(0).base-quantity = decimal("-100")
  assert.eq(rules(m), ("PEPPOL-EN16931-R121",))
})[
  #line-items[#item(
    [Schrauben],
    price: 4.99,
    quantity: 250,
    base-quantity: 100,
  )]
  #payment-goal(days: 14)
  #bank
]
