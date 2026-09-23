// Several exemption grounds in one VAT category.
//
// Bug: only the exemption grounds of the first item of a VAT category were
// kept. The grounds of the other items were silently dropped from the printed
// invoice and the XML (BT-120), so a seminar exempt under § 4 Nr. 21 UStG was
// declared exempt under § 4 Nr. 14 UStG, and an invoice whose first exempt
// item had no grounds was rejected (BR-E-10) although another item had them.
//
// Expected: every distinct ground survives. The XML joins them into the one
// exemption reason of the category; the printed invoice lists each ground and
// marks every item with its own.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#let check(test, theme: themes.blank, ..args, body) = invoice(
  theme: theme,
  locale: test-locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  ..args,
  data-test(
    test: (ctx, data) => {
      let li = loom.query.find-signal(data, "line-items")
      test(li, build-model(ctx + (zugferd: "en16931"), li.item-data))
    },
    body,
  ),
)

#let g14 = "Steuerfrei nach § 4 Nr. 14 UStG"
#let g21 = "Steuerfrei nach § 4 Nr. 21 UStG"

// --- 1. Exempt items with two different grounds ---
#check(
  (li, model) => {
    let exempt = li.item-data.taxes.at("0-E")
    assert.eq(exempt.grounds-list, (g14, g21))
    assert.eq(exempt.grounds, g14 + "; " + g21)
    assert.eq(exempt.missing-grounds, 0)
    assert.eq(model.taxes.first().reason, g14 + "; " + g21)
  },
  // The printed invoice: a marker per ground, on the items and the notes.
  theme: themes.blank.with(line-items: (ctx, data, body) => {
    assert.eq(data.items.map(i => i.tax.marker), ("*", "**", "*"))
    let exempt = data.taxes.first()
    assert.eq(exempt.grounds-list, (g14, g21))
    assert.eq(exempt.grounds-markers, ("*", "**"))
    assert.eq(exempt.itemized-grounds, true)
    body
  }),
)[
  #line-items[
    #item([Treatment], price: 90, tax: tax.exempt(grounds: g14))
    #item([Seminar], price: 300, tax: tax.exempt(grounds: g21))
    #item([Treatment 2], price: 50, tax: tax.exempt(grounds: [#g14]))
  ]
]

// --- 2. The grounds of a later item count as well ---
#check((li, model) => {
  let exempt = li.item-data.taxes.at("0-E")
  assert.eq(exempt.grounds, g21)
  assert.eq(exempt.missing-grounds, 1)
  assert.eq(model.taxes.first().reason, g21)
})[
  #line-items[
    #item([Treatment], price: 90, tax: tax.exempt())
    #item([Seminar], price: 300, tax: tax.exempt(grounds: g21))
  ]
]

// --- 3. Own export grounds are kept instead of the default reason ---
#check((li, model) => {
  let export = li.item-data.taxes.at("0-G")
  assert.eq(export.grounds, "Steuerfreie Ausfuhrlieferung § 4 Nr. 1a UStG")
  assert.eq(
    model.taxes.first().reason,
    "Steuerfreie Ausfuhrlieferung § 4 Nr. 1a UStG",
  )
})[
  #line-items[
    #item([Machine], price: 1000, tax: tax.export())
    #item(
      [Spare parts],
      price: 250,
      tax: tax.export(grounds: "Steuerfreie Ausfuhrlieferung § 4 Nr. 1a UStG"),
    )
  ]
]

// --- 4. The grounds inside a bundle are kept ---
#check((li, model) => {
  let exempt = li.item-data.taxes.at("0-E")
  assert.eq(exempt.grounds-list, (g14, g21))
  assert.eq(model.taxes.first().reason, g14 + "; " + g21)
})[
  #line-items[
    #bundle([Package])[
      #item([Treatment], price: 90, tax: tax.exempt(grounds: g14))
      #item([Seminar], price: 300, tax: tax.exempt(grounds: g21))
    ]
  ]
]

// --- 5. One ground in a category: no item markers (unchanged) ---
#check(
  (li, model) => {
    assert.eq(li.item-data.taxes.at("0-E").grounds, g14)
  },
  theme: themes.blank.with(line-items: (ctx, data, body) => {
    assert.eq(data.items.map(i => i.tax.marker), (none, none, none))
    let exempt = data.taxes.find(t => t.category == [E])
    assert.eq(exempt.marker, "*")
    assert.eq(exempt.itemized-grounds, false)
    body
  }),
)[
  #line-items[
    #item([Treatment], price: 90, tax: tax.exempt(grounds: g14))
    #item([Treatment 2], price: 50, tax: tax.exempt(grounds: g14))
    #item([Software], price: 100, tax: tax.vat(19%))
  ]
]
