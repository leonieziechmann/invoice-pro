// The precision of printed unit prices.
//
// Bug: with a finer `normalize.money-fine` (e.g. 6 decimals), the line total
// and the XML (BT-146) used the unit price 0.123456, but the printed unit
// price was always rounded to 4 decimals (0,1235 €). The printed invoice then
// contradicted its own line total (12,345 × 0,1235 ≠ 1.524,06) and the XML.
//
// Expected: the printed unit price is the price the line total is calculated
// with. With the default precision (4 decimals) nothing changes.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#let check(test, printed, locale: test-locale, body) = invoice(
  theme: themes.blank.with(line-items: (ctx, data, body) => {
    printed(data.items.map(i => i.price))
    body
  }),
  locale: locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  data-test(
    test: (ctx, data) => {
      let li = loom.query.find-signal(data, "line-items")
      test(li, build-model(ctx + (zugferd: "en16931"), li.item-data))
    },
    body,
  ),
)

#let d = decimal
// The number part of a printed price ("0,1235 €" -> "0,1235").
#let amount(price) = price.split(sym.space.nobreak.narrow).first()

// --- 1. A price with 6 decimals is printed with 6 decimals ---
#check(
  locale: test-locale.with(
    locale.custom.normalize(money-fine: x => calc.round(x, digits: 6)),
  ),
  (li, model) => {
    let (first, second, _) = li.item-data.items
    assert.eq(first.price, d("0.123456"))
    assert.eq(first.total, d("1524.06"))
    assert.eq(second.price, d("1.234568"))
    assert.eq(
      model.lines.map(l => l.price),
      (d("0.123456"), d("1.234568"), d("2.5")),
    )
  },
  printed => assert.eq(printed.map(amount), ("0,123456", "1,234568", "2,50")),
)[
  #line-items(tax: tax.vat(19%))[
    #item([Power], price: 0.123456, quantity: 12345)
    #item([Part], price: 1.2345678, quantity: 2)
    #item([Screw], price: 2.5, quantity: 3)
  ]
]

// --- 2. The default precision is unchanged ---
#check(
  (li, model) => {
    assert.eq(li.item-data.items.first().price, d("0.1235"))
    assert.eq(li.item-data.items.first().total, d("1524.61"))
  },
  printed => assert.eq(
    printed.map(amount),
    ("0,1235", "1,2350", "2,50"),
  ),
)[
  #line-items(tax: tax.vat(19%))[
    #item([Power], price: 0.123456, quantity: 12345)
    #item([Part], price: 1.235, quantity: 2)
    #item([Screw], price: 2.5, quantity: 3)
  ]
]
