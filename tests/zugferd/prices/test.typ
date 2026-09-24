// Unit prices (BT-146) and their base quantity (BT-149): the net price of a
// gross price keeps enough decimals that the quantity times the price is the
// line's net amount (PEPPOL-EN16931-R120), and the base quantity is above 0.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": profile-terms
#import "/src/zugferd/guard/roundtrip.typ": round-trip
#import "/tests/zugferd/harness.typ": (
  bank, build-xml, model-test, rules, xml-values,
)

// The line's net amount (BT-131) minus the quantity (BT-129) times the net
// price (BT-146) per base quantity (BT-149) and its charges, plus its
// allowances: what PEPPOL-EN16931-R120 compares with 0.02.
#let zero = decimal("0")
#let r120(line) = {
  let charges = line.charges.map(c => c.amount).sum(default: zero)
  let allowances = line.allowances.map(a => a.amount).sum(default: zero)
  (
    line.net
      - line.quantity * line.price / line.base-quantity
      - charges
      + allowances
  )
}

// --- 1. Gross prices: the net price has 6 decimals, or 3 more than the
// integer digits of the quantity (here 10 000 kWh: 8 decimals) ---
#model-test(
  locale: locale.de-de.with(locale.custom.normalize(
    money-fine: x => calc.round(x, digits: 6),
  )),
  tax-mode: "inclusive",
  model => {
    // 0.123456 / 1.19 = 0.1037445378...
    assert.eq(model.lines.first().price, decimal("0.10374454"))
    assert.eq(xml-values(model, "ram:ChargeAmount"), ("0.10374454",))
    assert(calc.abs(r120(model.lines.first())) <= decimal("0.02"))
    assert.eq(rules(model), ())
  },
)[
  #line-items[#item([Strom], price: 0.123456, quantity: 10000, unit: "kWh")]
  #payment-goal(days: 14)
  #bank
]

// The default fine rounding of 4 decimals, which the old net price of 4
// decimals (0.1038) broke by 0.18 (0.1038 x 10 000 = 1038.00 against the
// line's 1037.82).
#model-test(tax-mode: "inclusive", model => {
  assert.eq(model.lines.first().price, decimal("0.10378151"))
  assert.eq(model.lines.first().net, decimal("1037.82"))
  assert(calc.abs(r120(model.lines.first())) <= decimal("0.02"))
})[
  #line-items[#item([Strom], price: 0.1235, quantity: 10000, unit: "kWh")]
  #payment-goal(days: 14)
  #bank
]

// --- 2. 1000 x 9.99 incl. 19 % VAT: the net price 8.395 of 4 decimals gave
// 8395.00 against the line's 8394.96, beyond the 0.02 PEPPOL-EN16931-R120
// allows; with 7 decimals it is 8394.958 ---
#model-test(
  zugferd: "xrechnung",
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    vat-id: "DE987654321",
    email: "accounting@buyer.de",
    buyer-reference: "04011000-12345-67",
  ),
  tax-mode: "inclusive",
  model => {
    let line = model.lines.first()
    assert.eq(line.price, decimal("8.3949580"))
    assert.eq(xml-values(model, "ram:ChargeAmount"), ("8.394958",))
    assert.eq(line.net, decimal("8394.96"))
    assert(calc.abs(r120(line)) <= decimal("0.02"))
    assert.eq(rules(model), ())
  },
)[
  #line-items[#item([Schrauben], price: 9.99, quantity: 1000)]
  #payment-goal(days: 14)
  #bank
]

// The XML states every decimal of the net price: 2 000 000 000 calls at
// 0.0001 including 19 % VAT need 13 (0.0000840336134), which a writer of at
// most 12 rounded, so that the written price differed from the model's (the
// round trip of the strict mode reported it).
#model-test(
  tax-mode: "inclusive",
  zugferd-strict: true,
  model => {
    let line = model.lines.first()
    assert.eq(line.price, decimal("0.0000840336134"))
    assert.eq(xml-values(model, "ram:ChargeAmount"), ("0.0000840336134",))
    assert(calc.abs(r120(line)) <= decimal("0.02"))
    let root = xml(bytes(build-xml(model))).find(n => type(n) == dictionary)
    assert.eq(
      round-trip(
        root,
        model,
        profile-terms(model.payment, model.profile),
        strict: true,
      ),
      (),
    )
  },
)[
  #line-items[#item([API-Aufrufe], price: 0.0001, quantity: 2000000000)]
  #payment-goal(days: 14)
  #bank
]

// --- 3. The allowances and charges of a line are rounded to the side that
// keeps the line consistent: the line's amount, its quantity times its net
// price and its allowances and charges differ by less than 0.02 ---
#model-test(tax-mode: "inclusive", model => {
  for line in model.lines {
    assert(
      calc.abs(r120(line)) < decimal("0.02"),
      message: "line " + line.id + ": " + str(r120(line)),
    )
  }
})[
  #line-items[
    #for (i, price) in ("0.07", "1.13", "2.49", "19.99", "0.99").enumerate() {
      item(
        [Artikel #i],
        price: decimal(price),
        quantity: 7 + i,
        modifier: (
          discount([Rabatt A], amount: 3%),
          discount([Rabatt B], amount: 0.13),
          surcharge([Zuschlag], amount: 0.07),
        ),
      )
    }
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 4. The price base quantity (BT-149) is the quantity the price refers
// to. It is above 0 (PEPPOL-EN16931-R121 of XRechnung), as `item` and
// `bundle` refuse any other (tests/line-items/base-quantity), so the rules
// do not check it ---
#model-test(model => {
  assert.eq(model.lines.at(0).base-quantity, decimal("100"))
  assert.eq(xml-values(model, "ram:BasisQuantity"), ("100.00",))
  assert.eq(rules(model), ())
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
