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

// --- Test sender/recipient country inheritance from region ---
#{
  import "/src/logic/country.typ": normalize-party
  import "/src/lib.typ": country

  // 1. region as string
  let p1 = normalize-party((region: "FR"), "DE")
  assert.eq(p1.country.code, "FR")

  // 2. region as function (country)
  let p2 = normalize-party((region: country.at), "DE")
  assert.eq(p2.country.code, "AT")

  // 3. region as function (region)
  import "/src/locale/region/region.typ"
  let p3 = normalize-party((region: region.ch), "DE")
  assert.eq(p3.country.code, "CH")

  // 4. country overrides region
  let p4 = normalize-party((region: "FR", country: country.de), "DE")
  assert.eq(p4.country.code, "DE")
}

// --- Test ZUGFeRD allowance/charge (discount & surcharge) serialization ---
#{
  import "/src/zugferd/build.typ": (
    build-allowance-charge, build-header-allowance-charges, build-line-item,
    build-monetary-summation,
  )

  // 1. build-allowance-charge: ActualAmount is always a positive magnitude —
  //    ChargeIndicator alone carries the discount/surcharge sign.
  let discount-entry = build-allowance-charge(
    false,
    decimal("-50.00"),
    "Loyalty",
  )
  assert.eq(discount-entry.at("ram:ChargeIndicator"), (
    "udt:Indicator": "false",
  ))
  assert.eq(discount-entry.at("ram:ActualAmount"), "50.00")
  assert.eq(discount-entry.at("ram:Reason"), "Loyalty")
  assert.eq(discount-entry.at("ram:CategoryTradeTax", default: none), none)
  assert.eq(
    discount-entry.keys(),
    ("ram:ChargeIndicator", "ram:ActualAmount", "ram:Reason"),
  )

  // 2. build-allowance-charge: header-level surcharge with a tax category.
  let charge-entry = build-allowance-charge(
    true,
    decimal("25.00"),
    "Express Fee",
    tax-category: "S",
    tax-rate: 19%,
  )
  assert.eq(charge-entry.at("ram:ChargeIndicator"), ("udt:Indicator": "true"))
  assert.eq(charge-entry.at("ram:CategoryTradeTax"), (
    "ram:TypeCode": "VAT",
    "ram:CategoryCode": "S",
    "ram:RateApplicablePercent": "19.00",
  ))
  assert.eq(
    charge-entry.keys(),
    (
      "ram:ChargeIndicator",
      "ram:ActualAmount",
      "ram:Reason",
      "ram:CategoryTradeTax",
    ),
  )

  // 3. build-header-allowance-charges fans a global modifier's per-tax-category
  //    `split` out into one SpecifiedTradeAllowanceCharge per category (BR-53).
  let discounts = (
    (
      name: "Volume Discount",
      split: (
        "19-S": (tax: (rate: 19%, category: "S"), absolute: decimal("-10.00")),
        "7-AA": (tax: (rate: 7%, category: "AA"), absolute: decimal("-5.00")),
      ),
    ),
  )
  let header-entries = build-header-allowance-charges(discounts, ())
  assert.eq(header-entries.len(), 2)
  for entry in header-entries {
    assert.eq(entry.at("ram:ChargeIndicator"), ("udt:Indicator": "false"))
  }
  assert.eq(
    header-entries.map(e => e.at("ram:ActualAmount")).sorted(),
    ("10.00", "5.00").sorted(),
  )

  // 4. build-line-item embeds line-level SpecifiedTradeAllowanceCharge between
  //    ApplicableTradeTax and the monetary summation, only when non-empty.
  let item-discounts = (
    (
      name: "Rebate",
      description: none,
      type: "absolute",
      display: decimal("-20.00"),
      absolute: decimal("-20.00"),
    ),
  )
  let item-surcharges = (
    (
      name: "Rush Fee",
      description: none,
      type: "absolute",
      display: decimal("15.00"),
      absolute: decimal("15.00"),
    ),
  )

  let line-with-modifiers = build-line-item(
    1,
    "Widget",
    none,
    decimal("100.00"),
    decimal("1"),
    "C62",
    "S",
    19%,
    decimal("95.00"),
    item-discounts,
    item-surcharges,
  )
  let settlement = line-with-modifiers.at("ram:SpecifiedLineTradeSettlement")
  assert.eq(
    settlement.keys(),
    (
      "ram:ApplicableTradeTax",
      "ram:SpecifiedTradeAllowanceCharge",
      "ram:SpecifiedTradeSettlementLineMonetarySummation",
    ),
  )
  assert.eq(settlement.at("ram:SpecifiedTradeAllowanceCharge").len(), 2)

  let line-without-modifiers = build-line-item(
    1,
    "Widget",
    none,
    decimal("100.00"),
    decimal("1"),
    "C62",
    "S",
    19%,
    decimal("100.00"),
    (),
    (),
  )
  assert.eq(
    line-without-modifiers.at("ram:SpecifiedLineTradeSettlement").keys(),
    (
      "ram:ApplicableTradeTax",
      "ram:SpecifiedTradeSettlementLineMonetarySummation",
    ),
  )

  // 5. build-monetary-summation: LineTotalAmount vs TaxBasisTotalAmount only
  //    diverge (and Charge/AllowanceTotalAmount only appear) when there are
  //    document-level allowances/charges (BR-CO-13).
  let summation-plain = build-monetary-summation(
    decimal("1000.00"),
    decimal("1000.00"),
    decimal("1190.00"),
    decimal("190.00"),
    decimal("0"),
    decimal("0"),
    "EUR",
  )
  assert.eq(
    summation-plain.keys(),
    (
      "ram:LineTotalAmount",
      "ram:TaxBasisTotalAmount",
      "ram:TaxTotalAmount",
      "ram:GrandTotalAmount",
      "ram:DuePayableAmount",
    ),
  )

  let summation-modified = build-monetary-summation(
    decimal("1000.00"),
    decimal("950.00"),
    decimal("1130.50"),
    decimal("180.50"),
    decimal("100.00"),
    decimal("50.00"),
    "EUR",
  )
  assert.eq(
    summation-modified.keys(),
    (
      "ram:LineTotalAmount",
      "ram:ChargeTotalAmount",
      "ram:AllowanceTotalAmount",
      "ram:TaxBasisTotalAmount",
      "ram:TaxTotalAmount",
      "ram:GrandTotalAmount",
      "ram:DuePayableAmount",
    ),
  )
  assert.eq(summation-modified.at("ram:LineTotalAmount"), "1000.00")
  assert.eq(summation-modified.at("ram:TaxBasisTotalAmount"), "950.00")
  assert.eq(summation-modified.at("ram:ChargeTotalAmount"), "50.00")
  assert.eq(summation-modified.at("ram:AllowanceTotalAmount"), "100.00")
}

// --- Test backwards compatibility for 'street' ---
#{
  import "/src/logic/country.typ": normalize-party

  // 1. Check that 'street' is correctly transformed to 'address'
  let party-street = normalize-party(
    (name: "John Doe", street: "Musterstraße 1", city: "12345 Berlin"),
    "de",
  )
  assert.eq(party-street.address, "Musterstraße 1")
  assert.eq(party-street.address-lines, ("Musterstraße 1",))

  // 2. Check normal behavior with 'address'
  let party-address = normalize-party(
    (name: "John Doe", address: "Musterstraße 1", city: "12345 Berlin"),
    "de",
  )
  assert.eq(party-address.address, "Musterstraße 1")
  assert.eq(party-address.address-lines, ("Musterstraße 1",))

  // 3. Check mutual exclusion panic behavior
  assert.eq(
    catch(() => normalize-party(
      (
        name: "John Doe",
        street: "Musterstraße 1",
        address: "Musterstraße 2",
        city: "12345 Berlin",
      ),
      "de",
    )),
    "panicked with: \"Both 'street' and 'address' are populated for sender, but they are mutually exclusive.\"",
  )
  assert.eq(
    catch(() => normalize-party(
      (
        name: "John Doe",
        street: "Musterstraße 1",
        address: "Musterstraße 2",
        city: "12345 Berlin",
      ),
      "de",
      is-recipient: true,
    )),
    "panicked with: \"Both 'street' and 'address' are populated for recipient, but they are mutually exclusive.\"",
  )
}

// --- Test backwards compatibility for 'tax-nr' ---
#{
  import "/src/lib.typ": invoice, themes
  import "/tests/test-locale.typ": test-locale

  // Helper function to test invoice signature behavior
  let test-invoice(..args) = {
    invoice(
      theme: themes.blank,
      locale: test-locale,
      sender: (name: "Test Sender", address: "Street 1", city: "City"),
      recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
      ..args,
      [],
    )
  }

  // 1. Check that top-level tax-nr is supported and merges with sender details
  let res = catch(() => test-invoice(tax-nr: "123/456/78901"))
  assert.eq(res, none)

  // 2. Check mutual exclusion with sender.tax-nr
  let res-conflict = catch(() => {
    invoice(
      theme: themes.blank,
      locale: test-locale,
      sender: (
        name: "Test Sender",
        address: "Street 1",
        city: "City",
        tax-nr: "999/999/99999",
      ),
      recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
      tax-nr: "123/456/78901",
      [],
    )
  })
  assert.eq(
    res-conflict,
    "panicked with: \"Both the top-level 'tax-nr' parameter and 'sender.tax-nr' are populated, but they are mutually exclusive.\"",
  )

  // 3. Check mutual exclusion with zugferd (e-invoicing)
  let res-zugferd = catch(() => test-invoice(
    tax-nr: "123/456/78901",
    zugferd: "basic",
  ))
  assert.eq(
    res-zugferd,
    "panicked with: \"Top-level 'tax-nr' is not allowed when 'zugferd' (e-invoicing) is enabled. Please specify 'tax-nr' inside the 'sender' dictionary instead.\"",
  )
}
