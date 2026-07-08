#import "/src/loom-wrapper.typ": loom
#import "/src/lib.typ": locale, unit

// --- Test standard builder functions ---
#{
  let u-hour = unit.hour(locale.de-de)
  assert.eq(u-hour.code, "HUR")
  assert.eq(u-hour.name, "Stunde")

  let u-hour-en = unit.hour(locale.en-de)
  assert.eq(u-hour-en.code, "HUR")
  assert.eq(u-hour-en.name, "hour")

  let u-piece-de = unit.piece(locale.de-de)
  assert.eq(u-piece-de.code, "H87")
  assert.eq(u-piece-de.name, "Stück")

  let u-piece-es = unit.piece(locale.es-es)
  assert.eq(u-piece-es.code, "H87")
  assert.eq(u-piece-es.name, "unidad")

  let u-piece-fr = unit.piece(locale.fr-fr)
  assert.eq(u-piece-fr.code, "H87")
  assert.eq(u-piece-fr.name, "pièce")

  let u-piece-it = unit.piece(locale.it-it)
  assert.eq(u-piece-it.code, "H87")
  assert.eq(u-piece-it.name, "pezzo")

  let u-set-de = unit.unit-set(locale.de-de)
  assert.eq(u-set-de.code, "SET")
  assert.eq(u-set-de.name, "Satz")
}

// --- Test alias matching ---
#{
  assert.eq(unit.unit-set, unit.sets)
  assert.eq(unit.unit-set, unit.set-unit)
  assert.eq(unit.h, unit.hour)
  assert.eq(unit.d, unit.day)
  assert.eq(unit.mo, unit.month)
  assert.eq(unit.y, unit.year)
  assert.eq(unit.kg, unit.kilogram)
  assert.eq(unit.g, unit.gram)
  assert.eq(unit.t, unit.tonne)
  assert.eq(unit.m, unit.metre)
  assert.eq(unit.sqm, unit.square-metre)
  assert.eq(unit.m2, unit.square-metre)
  assert.eq(unit.mm, unit.millimetre)
  assert.eq(unit.cm, unit.centimetre)
  assert.eq(unit.km, unit.kilometre)
  assert.eq(unit.l, unit.litre)
  assert.eq(unit.m3, unit.cubic-metre)
  assert.eq(unit.stk, unit.piece)
  assert.eq(unit.pc, unit.piece)
  assert.eq(unit.pcs, unit.piece)
  assert.eq(unit.ls, unit.lump-sum)
  assert.eq(unit.lumpsum, unit.lump-sum)
  assert.eq(unit.flat, unit.lump-sum)
}

// --- Test evaluated locale dict support ---
#{
  // Simulate an evaluated locale context dictionary
  let dummy-locale = (
    strings: (
      units: (
        hour: "DummyHour",
      ),
    ),
  )
  assert.eq(unit.hour(dummy-locale), (
    code: "HUR",
    name: "DummyHour",
    display: "DummyHour",
  ))
}

// --- Test ZUGFeRD address lines formatting ---
#{
  import "/src/zugferd/build.typ": (
    build-buyer-trade-party, build-seller-trade-party,
  )

  // 1. Test Seller Trade Party with single string address
  let seller-single = build-seller-trade-party(
    "Name",
    "Street 1",
    "City",
    "12345",
    "DE",
    "12/345/6789",
    "DE987654321",
    true,
  )
  assert.eq(
    seller-single.at("ram:PostalTradeAddress").at("ram:LineOne"),
    "Street 1",
  )
  assert.eq(
    seller-single.at("ram:PostalTradeAddress").at("ram:LineTwo", default: none),
    none,
  )

  // 2. Test Seller Trade Party with array address <= 3 elements
  let seller-array-3 = build-seller-trade-party(
    "Name",
    ("Street 1", "Suite 100", "Floor 3"),
    "City",
    "12345",
    "DE",
    "12/345/6789",
    "DE987654321",
    true,
  )
  assert.eq(
    seller-array-3.at("ram:PostalTradeAddress").at("ram:LineOne"),
    "Street 1",
  )
  assert.eq(
    seller-array-3.at("ram:PostalTradeAddress").at("ram:LineTwo"),
    "Suite 100",
  )
  assert.eq(
    seller-array-3.at("ram:PostalTradeAddress").at("ram:LineThree"),
    "Floor 3",
  )

  // 3. Test Seller Trade Party with array address > 3 elements
  let seller-array-4 = build-seller-trade-party(
    "Name",
    ("Street 1", "Suite 100", "Floor 3", "Apartment 4B"),
    "City",
    "12345",
    "DE",
    "12/345/6789",
    "DE987654321",
    true,
  )
  assert.eq(
    seller-array-4.at("ram:PostalTradeAddress").at("ram:LineOne"),
    "Street 1",
  )
  assert.eq(
    seller-array-4.at("ram:PostalTradeAddress").at("ram:LineTwo"),
    "Suite 100",
  )
  assert.eq(
    seller-array-4.at("ram:PostalTradeAddress").at("ram:LineThree"),
    "Floor 3, Apartment 4B",
  )

  // 4. Test Buyer Trade Party with array address
  let buyer-array = build-buyer-trade-party(
    "Name",
    ("Street A", "Suite B"),
    "City",
    "54321",
    "FR",
    "FR123456789",
    true,
  )
  assert.eq(
    buyer-array.at("ram:PostalTradeAddress").at("ram:LineOne"),
    "Street A",
  )
  assert.eq(
    buyer-array.at("ram:PostalTradeAddress").at("ram:LineTwo"),
    "Suite B",
  )
  assert.eq(
    buyer-array.at("ram:PostalTradeAddress").at("ram:LineThree", default: none),
    none,
  )
}

// --- Test items and bundles resolving units via ctx ---
#import "/tests/data-test.typ": data-test
#import "/tests/test-locale.typ": test-locale
#import "/src/lib.typ": bundle, invoice, item, line-items, themes

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
)

#data-test(test: (ctx, data) => {
  let line-items = loom.query.find-signal(data, "line-items")
  let items = line-items.item-data.items

  // Verify first item (resolved with unit.hour function)
  assert.eq(items.at(0).unit, (code: "HUR", name: "hour", display: "hour"))

  // Verify second item (resolved with unit.m2 function)
  assert.eq(items.at(1).unit, (
    code: "MTK",
    name: "square metre",
    display: "square metre",
  ))

  // Verify bundle unit (resolved with unit.sets function)
  let bundles = (items.at(2),)
  assert.eq(bundles.at(0).unit, (code: "SET", name: "set", display: "set"))

  // Verify custom dict optional name fallback
  assert.eq(items.at(3).unit, (
    code: "MY_CODE",
    name: "MyCustomDisplay",
    display: "MyCustomDisplay",
  ))
})[
  #line-items[
    #item([Development Work], price: 100.00, quantity: 8, unit: unit.hour)
    #item([Area Painting], price: 15.00, quantity: 20, unit: unit.m2)
    #bundle([License Bundle], unit: unit.sets)[
      #item([Core License], price: 400.00, quantity: 1)
      #item([Support Addon], price: 50.00, quantity: 1)
    ]
    #item([Custom Dict Item], price: 10.00, quantity: 1, unit: (
      display: "MyCustomDisplay",
      code: "MY_CODE",
    ))
  ]
]
