#import "/src/loom-wrapper.typ": loom
#import "/src/lib.typ": locale, unit

// --- Test standard builder functions ---
#{
  let u-hour = unit.hour(locale.de-de)
  assert.eq(u-hour.code, "HUR")
  assert.eq(u-hour.name, (singular: "Stunde", plural: "Stunden"))

  let u-hour-en = unit.hour(locale.en-de)
  assert.eq(u-hour-en.code, "HUR")
  assert.eq(u-hour-en.name, (singular: "hour", plural: "hours"))

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
  assert.eq(u-set-de.name, (singular: "Satz", plural: "Sätze"))
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
  import "/src/zugferd/build.typ": build-buyer-trade-party, build-postal-address
  import "/src/zugferd/model.typ": party-model
  import "/src/zugferd/profile.typ": resolve-profile
  import "/src/logic/country.typ": normalize-party

  let party(address) = party-model(normalize-party(
    (
      name: "Name",
      address: address,
      city: "12345 City",
      vat-id: "DE987654321",
    ),
    "de",
  ))
  let postal(address) = build-postal-address(party(address).address)

  // 1. A single string address maps to ram:LineOne, in XSD order
  let single = postal("Street 1")
  assert.eq(single.at("ram:LineOne"), "Street 1")
  assert.eq(single.at("ram:LineTwo", default: none), none)
  assert.eq(
    single.keys(),
    ("ram:PostcodeCode", "ram:LineOne", "ram:CityName", "ram:CountryID"),
  )
  assert.eq(single.at("ram:PostcodeCode"), "12345")
  assert.eq(single.at("ram:CityName"), "City")
  assert.eq(single.at("ram:CountryID"), "DE")

  // 2. An array address with <= 3 elements maps to one line each
  let array-3 = postal(("Street 1", "Suite 100", "Floor 3"))
  assert.eq(array-3.at("ram:LineOne"), "Street 1")
  assert.eq(array-3.at("ram:LineTwo"), "Suite 100")
  assert.eq(array-3.at("ram:LineThree"), "Floor 3")

  // 3. Further elements are joined into ram:LineThree
  let array-4 = postal(("Street 1", "Suite 100", "Floor 3", "Apartment 4B"))
  assert.eq(array-4.at("ram:LineOne"), "Street 1")
  assert.eq(array-4.at("ram:LineTwo"), "Suite 100")
  assert.eq(array-4.at("ram:LineThree"), "Floor 3, Apartment 4B")

  // 4. Content lines are written as their plain text
  let styled = postal(([*Street* 1], [Suite #h(1em) 100]))
  assert.eq(styled.at("ram:LineOne"), "Street 1")
  assert.eq(styled.at("ram:LineTwo"), "Suite 100")

  // 5. Buyer Trade Party with array address
  let buyer-array = build-buyer-trade-party(
    party(("Street A", "Suite B")),
    resolve-profile("en16931", "FR"),
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

  // 5. Test international country formatting: country code prefixing (like FR - France)
  let p5 = normalize-party(
    (region: "FR", city: "75001 Paris"),
    "DE",
    is-recipient: true,
    sender-country-code: "DE",
  )
  assert.eq(p5.city, [75001 Paris \ ] + "FR - France")

  // 6. Test show-always behavior override
  let de-always = country.de.with(show-always: true)
  let p6 = normalize-party(
    (region: "DE", city: "10115 Berlin", country: de-always),
    "DE",
  )
  assert.eq(p6.city, [10115 Berlin \ ] + "DE - Deutschland")
}

// --- Test ZUGFeRD allowance/charge (discount & surcharge) serialization ---
#{
  import "/src/zugferd/build.typ": (
    build-allowance-charge, build-header-allowance-charges, build-line-item,
    build-monetary-summation,
  )
  import "/src/zugferd/model.typ": document-allowance-charges, line-model
  import "/src/zugferd/profile.typ": resolve-profile

  let profile = resolve-profile("en16931", "FR")

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

  // 3. A reason is mandatory (BR-33, BR-38) even if the modifier name has no
  //    text, and amounts not subject to VAT carry no rate (BR-O-06, BR-O-07).
  let unnamed = build-allowance-charge(
    false,
    decimal("5"),
    [],
    tax-category: "O",
    tax-rate: 0%,
  )
  assert.eq(unnamed.at("ram:Reason"), "Discount")
  assert.eq(unnamed.at("ram:CategoryTradeTax"), (
    "ram:TypeCode": "VAT",
    "ram:CategoryCode": "O",
  ))
  assert.eq(
    build-allowance-charge(true, decimal("5"), none).at("ram:Reason"),
    "Surcharge",
  )

  // 4. A global modifier's per-tax-category `split` is fanned out into one
  //    SpecifiedTradeAllowanceCharge per category (BR-53).
  let discounts = (
    (
      name: "Volume Discount",
      split: (
        "19-S": (tax: (rate: 19%, category: "S"), absolute: decimal("-10.00")),
        "7-S": (tax: (rate: 7%, category: "S"), absolute: decimal("-5.00")),
      ),
    ),
  )
  let header-entries = build-header-allowance-charges(
    document-allowance-charges(discounts, ()),
  )
  assert.eq(header-entries.len(), 2)
  for entry in header-entries {
    assert.eq(entry.at("ram:ChargeIndicator"), ("udt:Indicator": "false"))
  }
  assert.eq(
    header-entries.map(e => e.at("ram:ActualAmount")).sorted(),
    ("10.00", "5.00").sorted(),
  )

  // 5. Gross amounts (tax-mode "inclusive") are converted to net per category.
  assert.eq(
    document-allowance-charges(discounts, (), inclusive: true).map(e => {
      e.amount
    }),
    (decimal("8.40"), decimal("4.67")),
  )

  // 6. build-line-item embeds line-level SpecifiedTradeAllowanceCharge between
  //    ApplicableTradeTax and the monetary summation, only when non-empty.
  let widget(..fields) = line-model(
    (
      pos: "1",
      name: "Widget",
      price: decimal("100.00"),
      quantity: decimal("1"),
      base-quantity: decimal("1"),
      unit: "C62",
      tax: (rate: 19%, category: "S"),
      total: decimal("100.00"),
      discounts: (),
      surcharge: (),
      item-id: none,
    )
      + fields.named(),
    0,
  )
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
    widget(
      total: decimal("95.00"),
      discounts: item-discounts,
      surcharge: item-surcharges,
    ),
    profile,
  )
  assert.eq(
    line-with-modifiers.at("ram:SpecifiedLineTradeAgreement").keys(),
    ("ram:NetPriceProductTradePrice",),
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

  let line-without-modifiers = build-line-item(widget(), profile)
  assert.eq(
    line-without-modifiers.at("ram:SpecifiedLineTradeSettlement").keys(),
    (
      "ram:ApplicableTradeTax",
      "ram:SpecifiedTradeSettlementLineMonetarySummation",
    ),
  )

  // 7. A price per base quantity (BT-149) is stated with the unit of the
  //    billed quantity, and prices keep their decimals (BT-146).
  let per-hundred = build-line-item(
    widget(
      price: decimal("4.9912"),
      quantity: decimal("250"),
      base-quantity: decimal("100"),
      unit: "H87",
      total: decimal("12.48"),
    ),
    profile,
  )
  assert.eq(
    per-hundred
      .at("ram:SpecifiedLineTradeAgreement")
      .at("ram:NetPriceProductTradePrice"),
    (
      "ram:ChargeAmount": "4.9912",
      "ram:BasisQuantity": ("@unitCode": "H87", "": "100.00"),
    ),
  )
  assert.eq(per-hundred.at("ram:SpecifiedLineTradeDelivery"), (
    "ram:BilledQuantity": ("@unitCode": "H87", "": "250.00"),
  ))

  // 8. BR-27: a negative price is written as a positive price of a negative
  //    quantity, which keeps the line total.
  let refund = widget(
    price: decimal("-50"),
    quantity: decimal("2"),
    total: decimal("-100"),
  )
  assert.eq(
    (refund.price, refund.quantity, refund.net),
    (decimal("50"), decimal("-2"), decimal("-100")),
  )

  // 9. Lines not subject to VAT carry no rate (BR-O-05).
  assert.eq(
    build-line-item(widget(tax: (rate: 0%, category: "O")), profile)
      .at("ram:SpecifiedLineTradeSettlement")
      .at("ram:ApplicableTradeTax"),
    ("ram:TypeCode": "VAT", "ram:CategoryCode": "O"),
  )

  // 10. build-monetary-summation: LineTotalAmount vs TaxBasisTotalAmount only
  //     diverge (and Charge/AllowanceTotalAmount only appear) when there are
  //     document-level allowances/charges (BR-CO-13).
  let totals(line, net, gross, tax, allowance, charge, prepaid: 0) = (
    line: decimal(line),
    net: decimal(net),
    gross: decimal(gross),
    tax: decimal(tax),
    allowance: decimal(allowance),
    charge: decimal(charge),
    prepaid: decimal(prepaid),
    due: decimal(gross) - decimal(prepaid),
  )
  let summation-plain = build-monetary-summation(
    totals("1000.00", "1000.00", "1190.00", "190.00", "0", "0"),
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
    totals("1000.00", "950.00", "1130.50", "180.50", "100.00", "50.00"),
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

  // 11. build-monetary-summation without breakdown (MINIMUM profile): only
  //     BT-109, BT-110, BT-112 and BT-115; the amount due still subtracts
  //     prepayments although TotalPrepaidAmount (BT-113) is omitted.
  let summation-minimum = build-monetary-summation(
    totals(
      "1000.00",
      "950.00",
      "1130.50",
      "180.50",
      "100.00",
      "50.00",
      prepaid: "300.00",
    ),
    "EUR",
    include-breakdown: false,
  )
  assert.eq(
    summation-minimum.keys(),
    (
      "ram:TaxBasisTotalAmount",
      "ram:TaxTotalAmount",
      "ram:GrandTotalAmount",
      "ram:DuePayableAmount",
    ),
  )
  assert.eq(summation-minimum.at("ram:DuePayableAmount"), "830.50")
}

// --- Test ZUGFeRD item identifiers (BT-155, BT-156, BT-157) ---
#{
  import "/src/utils/coercion.typ": to-item-id
  import "/src/zugferd/build.typ": build-line-item
  import "/src/zugferd/model.typ": line-model
  import "/src/zugferd/profile.typ": resolve-profile

  // 1. A plain string is the seller's article number, never a GTIN; dictionary
  //    item-ids are kept instead of being dropped.
  assert.eq(to-item-id("ART-4711"), (
    seller: "ART-4711",
    buyer: none,
    standard: none,
  ))
  assert.eq(to-item-id((seller: "KB-001")), (
    seller: "KB-001",
    buyer: none,
    standard: none,
  ))
  assert.eq(to-item-id((seller: "S", buyer: "B", standard: "4006381333931")), (
    seller: "S",
    buyer: "B",
    standard: "4006381333931",
  ))
  assert.eq(to-item-id(none), none)
  assert.eq(to-item-id(auto), auto)

  let product(item-id, profile: "en16931") = build-line-item(
    line-model(
      (
        pos: "1",
        name: "Widget",
        price: decimal("100.00"),
        quantity: decimal("1"),
        base-quantity: decimal("1"),
        unit: "C62",
        tax: (rate: 19%, category: "S"),
        total: decimal("100.00"),
        discounts: (),
        surcharge: (),
        item-id: to-item-id(item-id),
      ),
      0,
    ),
    resolve-profile(profile, "FR"),
  ).at("ram:SpecifiedTradeProduct")

  // 2. IDs follow the TradeProduct XSD sequence and precede ram:Name.
  let full = product((seller: "S", buyer: "B", standard: "4006381333931"))
  assert.eq(
    full.keys(),
    (
      "ram:GlobalID",
      "ram:SellerAssignedID",
      "ram:BuyerAssignedID",
      "ram:Name",
    ),
  )
  assert.eq(full.at("ram:GlobalID"), (
    "@schemeID": "0160",
    "": "4006381333931",
  ))
  assert.eq(full.at("ram:SellerAssignedID"), "S")
  assert.eq(full.at("ram:BuyerAssignedID"), "B")

  let plain = product("ART-4711")
  assert.eq(plain.keys(), ("ram:SellerAssignedID", "ram:Name"))
  assert.eq(plain.at("ram:SellerAssignedID"), "ART-4711")

  assert.eq(product(none).keys(), ("ram:Name",))
  assert.eq(product((seller: "", standard: none)).keys(), ("ram:Name",))

  // 3. The BASIC profile's TradeProduct only allows GlobalID.
  assert.eq(
    product(
      (seller: "S", buyer: "B", standard: "4006381333931"),
      profile: "basic",
    ).keys(),
    ("ram:GlobalID", "ram:Name"),
  )
  assert.eq(product("ART-4711", profile: "basic").keys(), ("ram:Name",))
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

// --- Test date coercion ---
#{
  import "/src/utils/coercion.typ": to-date

  let d1 = datetime(year: 2026, month: 7, day: 1)
  let d2 = datetime(year: 2026, month: 7, day: 5)

  assert.eq(to-date(d1), d1)
  assert.eq(to-date((d1, d2)), (d1, d2))
  assert.eq(to-date(auto), auto)
  assert.eq(to-date(none), none)
}

// --- Test ZUGFeRD delivery date determination ---
#{
  import "/src/zugferd/build.typ": determine-delivery-dates

  let ctx = (invoice-date: datetime(year: 2026, month: 7, day: 9))

  // 1. Empty items list
  assert.eq(
    determine-delivery-dates(ctx, ()),
    (date: datetime(year: 2026, month: 7, day: 9), period: none),
  )

  // 2. Items with no date / auto
  assert.eq(
    determine-delivery-dates(ctx, (
      (name: "A", date: auto),
      (name: "B", date: none),
    )),
    (date: datetime(year: 2026, month: 7, day: 9), period: none),
  )

  // 3. Items with single shared date and an undated item, which does not
  // count (as for the printed service period)
  assert.eq(
    determine-delivery-dates(ctx, (
      (name: "A", date: datetime(year: 2026, month: 7, day: 1)),
      (name: "B", date: datetime(year: 2026, month: 7, day: 1)),
      (name: "C", date: auto),
    )),
    (date: datetime(year: 2026, month: 7, day: 1), period: none),
  )

  // 4. Items with single shared date (without auto falling back to invoice-date)
  assert.eq(
    determine-delivery-dates(ctx, (
      (name: "A", date: datetime(year: 2026, month: 7, day: 1)),
      (name: "B", date: datetime(year: 2026, month: 7, day: 1)),
    )),
    (date: datetime(year: 2026, month: 7, day: 1), period: none),
  )

  // 5. Items with range / multiple dates
  assert.eq(
    determine-delivery-dates(ctx, (
      (
        name: "A",
        date: (
          datetime(year: 2026, month: 7, day: 1),
          datetime(year: 2026, month: 7, day: 5),
        ),
      ),
      (name: "B", date: datetime(year: 2026, month: 7, day: 3)),
    )),
    (
      date: none,
      period: (
        datetime(year: 2026, month: 7, day: 1),
        datetime(year: 2026, month: 7, day: 5),
      ),
    ),
  )
}

// --- Test dynamic references module ---
#{
  import "/src/public/references.typ"

  let mock-locale = (
    strings: (
      reference: (
        tax-number: "Mock Tax ID",
        vat-id: "Mock VAT ID",
        invoice-number: "Mock Invoice Number",
        invoice-date: "Mock Date",
        service-time: "Mock Service Time",
      ),
    ),
    format: (
      date: d => str(d.year()) + "-" + str(d.month()) + "-" + str(d.day()),
    ),
  )

  let mock-ctx = (
    locale: mock-locale,
    sender: (
      tax-nr: "123-TAX",
      vat-id: "DE987654",
    ),
    invoice-nr: "INV-001",
    invoice-date: datetime(year: 2026, month: 7, day: 15),
    items: (
      (name: "Item 1", date: datetime(year: 2026, month: 7, day: 10)),
      (
        name: "Item 2",
        date: (
          datetime(year: 2026, month: 7, day: 12),
          datetime(year: 2026, month: 7, day: 14),
        ),
      ),
    ),
  )

  // 1. Test basic resolution with auto values
  assert.eq((references.tax-nr())(mock-ctx), ("Mock Tax ID", "123-TAX"))
  assert.eq((references.vat-id())(mock-ctx), ("Mock VAT ID", "DE987654"))
  assert.eq((references.invoice-nr())(mock-ctx), (
    "Mock Invoice Number",
    "INV-001",
  ))
  assert.eq((references.invoice-date())(mock-ctx), ("Mock Date", "2026-7-15"))
  assert.eq((references.service-time())(mock-ctx), (
    "Mock Service Time",
    "2026-7-10 " + sym.dash + " 2026-7-14",
  ))

  // 2. Test resolution with overrides
  assert.eq(
    (references.tax-nr(label: "Custom Tax Label", value: "TAX-CUSTOM"))(
      mock-ctx,
    ),
    (
      "Custom Tax Label",
      "TAX-CUSTOM",
    ),
  )
  assert.eq((references.vat-id(value: "VAT-CUSTOM"))(mock-ctx), (
    "Mock VAT ID",
    "VAT-CUSTOM",
  ))
  assert.eq((references.invoice-date(label: "Custom Date Label"))(mock-ctx), (
    "Custom Date Label",
    "2026-7-15",
  ))
  assert.eq((references.service-time(value: "Custom Service Time"))(mock-ctx), (
    "Mock Service Time",
    "Custom Service Time",
  ))

  // 3. Test service-time fallback to invoice-date when no items/dates are present
  let mock-ctx-no-dates = mock-ctx
  mock-ctx-no-dates.items = ()
  assert.eq((references.service-time())(mock-ctx-no-dates), (
    "Mock Service Time",
    "2026-7-15",
  ))
}

// --- Test bank-details BIC visibility ---
#{
  import "/src/themes/base-theme/bank-details.typ": render-bank-details
  import "/src/lib.typ": locale
  import "/src/locale/lang/base.typ": base-language
  import "/src/locale/region/base.typ": base-region

  let ctx = (
    locale: (locale.de-de)(base-language, base-region),
  )

  let base-view = (
    sender: (
      name: "Max Mustermann",
      bank: "Musterbank",
      iban: "DE75512108001245126199",
      bic: "",
    ),
    qr-code: (
      size: 5em,
      display: true,
    ),
    reference: "INV-001",
    show-reference: true,
    payment-amount: 100.0,
  )

  // 1. When BIC is empty / omitted, BIC line should not be rendered
  let res-no-bic = render-bank-details(ctx, base-view)
  let str-no-bic = repr(res-no-bic)
  assert(not str-no-bic.contains("[BIC]"))
  assert(not str-no-bic.contains("SOLADEST600"))

  // 2. When BIC is provided, BIC line should be rendered
  let view-with-bic = base-view
  view-with-bic.sender.bic = "SOLADEST600"
  let res-with-bic = render-bank-details(ctx, view-with-bic)
  let str-with-bic = repr(res-with-bic)
  assert(str-with-bic.contains("[BIC]"))
  assert(str-with-bic.contains("SOLADEST600"))

  // 3. When unstructured text is provided instead of reference
  let view-with-text = base-view
  view-with-text.reference = none
  view-with-text.text = "Rechnung 2026-001"
  let res-with-text = render-bank-details(ctx, view-with-text)
  let str-with-text = repr(res-with-text)
  assert(str-with-text.contains("Rechnung 2026-001"))
}


// --- Test ZUGFeRD seller trade party tax registrations (outside-scope and fallback) ---
#{
  import "/src/zugferd/build.typ": build-seller-trade-party
  import "/src/zugferd/model.typ": seller-model
  import "/src/zugferd/profile.typ": resolve-profile
  import "/src/logic/country.typ": normalize-party

  let seller(outside-scope: false, ..fields) = build-seller-trade-party(
    seller-model(
      normalize-party(
        (
          name: "Seller GmbH",
          address: ("Street 1",),
          city: "80339 München",
        )
          + fields.named(),
        "de",
      ),
      use-vat-id: not outside-scope,
    ),
    resolve-profile("en16931", "FR"),
  )
  let registrations(party) = party.at(
    "ram:SpecifiedTaxRegistration",
    default: none,
  )

  // 1. Both vat-id and tax-nr provided (standard case)
  let party-both = seller(tax-nr: "123/456/78901", vat-id: "DE123456789")
  assert.eq(registrations(party-both), (
    ("ram:ID": ("@schemeID": "VA", "": "DE123456789")),
    ("ram:ID": ("@schemeID": "FC", "": "123/456/78901")),
  ))
  assert.eq(party-both.at("ram:ID", default: none), none)

  // 2. Only vat-id provided, not outside-scope
  assert.eq(registrations(seller(vat-id: "DE123456789")), (
    ("ram:ID": ("@schemeID": "VA", "": "DE123456789")),
  ))

  // 3. vat-id provided, no tax-nr, outside-scope (used to panic on none.len())
  let party-outside-no-tax-nr = seller(
    vat-id: "DE123456789",
    outside-scope: true,
  )
  assert.eq(registrations(party-outside-no-tax-nr), none)
  assert.eq(party-outside-no-tax-nr.at("ram:ID", default: none), none)

  // 4. vat-id and tax-nr, outside-scope: the VAT ID is dropped (BR-O-02) and
  //    the tax number is kept, which also identifies the seller (BT-29)
  let party-outside-with-tax-nr = seller(
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    outside-scope: true,
  )
  assert.eq(registrations(party-outside-with-tax-nr), (
    ("ram:ID": ("@schemeID": "FC", "": "123/456/78901")),
  ))
  assert.eq(
    party-outside-with-tax-nr.at("ram:ID", default: none),
    "123/456/78901",
  )

  // 5. Neither vat-id nor tax-nr provided
  assert.eq(registrations(seller()), none)

  // 6. An explicit seller identifier (BT-29) needs no tax registration (#42)
  let party-id = seller(id: "70025")
  assert.eq(party-id.at("ram:ID"), "70025")
  assert.eq(registrations(party-id), none)

  // 7. The explicit identifier wins over the tax number fallback
  let party-id-tax-nr = seller(id: "70025", tax-nr: "12345")
  assert.eq(party-id-tax-nr.at("ram:ID"), "70025")
  assert.eq(registrations(party-id-tax-nr), (
    ("ram:ID": ("@schemeID": "FC", "": "12345")),
  ))

  // 8. A global identifier with scheme (e.g. a GLN) precedes the name
  let party-gln = seller(
    vat-id: "DE123456789",
    global-id: (scheme: "0088", id: "4000001123452"),
  )
  assert.eq(party-gln.at("ram:GlobalID"), (
    "@schemeID": "0088",
    "": "4000001123452",
  ))
  assert.eq(party-gln.keys().slice(0, 2), ("ram:GlobalID", "ram:Name"))
}


// --- Test ZUGFeRD validation lists every problem at once (BT-49, BT-10, BG-6, BT-41, BT-42, BT-43, BT-34, BR-CO-26) ---
#{
  import "/src/lib.typ": (
    bank-details, country, invoice, item, line-items, locale, payment-goal, tax,
    themes,
  )

  // Repro invoice from bug report (missing BT-49, BT-10, BG-6), as XRechnung
  let test-e-invoice(
    sender-overrides: (:),
    recipient-overrides: (:),
    zugferd: "xrechnung",
  ) = {
    let base-sender = (
      name: "Seller GmbH",
      address: "Street 1",
      city: (name: "München", post-code: "80339"),
      country: country.de,
      vat-id: "DE123456789",
    )
    let base-recipient = (
      name: "Buyer GmbH",
      address: "Weg 5",
      city: (name: "Berlin", post-code: "10115"),
      country: country.de,
    )
    invoice(
      theme: themes.blank,
      locale: locale.de-de,
      zugferd: zugferd,
      sender: base-sender + sender-overrides,
      recipient: base-recipient + recipient-overrides,
      invoice-nr: "2026-01",
      [
        #line-items[
          #item([Consulting], price: 100, quantity: 1, tax: tax.vat(19%))
        ]
        #payment-goal(days: 14)
        #bank-details(
          bank: "Musterbank",
          iban: "DE89370400440532013000",
          bic: "BANK123X",
        )
      ],
    )
  }

  // The rules of all errors in the compiler error, sorted; `()` if the
  // invoice compiles.
  let failed-rules(..args) = {
    let message = catch(() => test-e-invoice(..args))
    if message == none { return () }
    assert(
      message.starts-with("assertion failed: The e-invoice"),
      message: "Unexpected error: " + message,
    )
    message
      .split("\nWarnings:")
      .first()
      .matches(regex("\n  [0-9]+\\. \\[([A-Za-z0-9-]+)\\]"))
      .map(m => m.captures.first())
      .sorted()
  }

  // 1. Initial bug repro: all missing XRechnung fields are reported at once
  assert.eq(
    failed-rules(),
    ("BR-DE-15", "BR-DE-2", "PEPPOL-EN16931-R010").sorted(),
  )

  // 2. Add email to recipient: buyer reference (BT-10) and seller contact
  //    (BG-6) are still missing
  assert.eq(
    failed-rules(recipient-overrides: (email: "buyer@example.de")),
    ("BR-DE-15", "BR-DE-2"),
  )

  // 3. Add buyer-reference to recipient: only the seller contact (BG-6) is left
  assert.eq(
    failed-rules(
      recipient-overrides: (
        email: "buyer@example.de",
        buyer-reference: "DE123456789-12345-12",
      ),
    ),
    ("BR-DE-2",),
  )

  // 4. Incomplete seller contact (missing name BT-41, phone BT-42, email BT-43)
  let complete-recipient = (
    email: "buyer@example.de",
    buyer-reference: "DE123456789-12345-12",
  )
  assert.eq(
    failed-rules(
      recipient-overrides: complete-recipient,
      sender-overrides: (
        contact: (phone: "+49 89 123456", email: "seller@example.de"),
      ),
    ),
    ("BR-DE-5",),
  )
  assert.eq(
    failed-rules(
      recipient-overrides: complete-recipient,
      sender-overrides: (
        contact: (name: "Max Mustermann", email: "seller@example.de"),
      ),
    ),
    ("BR-DE-6",),
  )
  assert.eq(
    failed-rules(
      recipient-overrides: complete-recipient,
      sender-overrides: (
        contact: (name: "Max Mustermann", phone: "+49 89 123456"),
      ),
    ),
    ("BR-DE-7",),
  )

  // 5. Without VAT ID and tax number, the seller electronic address (BT-34) is
  //    derived from the contact email, but the seller can neither be
  //    identified (BR-CO-26) nor charge VAT (BR-S-02)
  assert.eq(
    failed-rules(
      recipient-overrides: complete-recipient,
      sender-overrides: (
        vat-id: none,
        contact: (
          name: "Max Mustermann",
          phone: "+49 89 123456",
          email: "seller@example.de",
        ),
      ),
    ),
    ("BR-CO-26", "BR-S-02"),
  )

  // 6. ... and without any email, the seller electronic address (BT-34) and
  //    the contact email (BT-43) are missing as well
  assert.eq(
    failed-rules(
      recipient-overrides: complete-recipient,
      sender-overrides: (
        vat-id: none,
        contact-name: "Max Mustermann",
        phone: "+49 89 123456",
        email: none,
      ),
    ),
    ("BR-CO-26", "BR-DE-7", "BR-S-02", "PEPPOL-EN16931-R020").sorted(),
  )

  // 7. Complete valid invoice with all mandatory fields satisfied
  assert.eq(
    failed-rules(
      recipient-overrides: complete-recipient,
      sender-overrides: (
        contact: (
          name: "Max Mustermann",
          phone: "+49 89 123456",
          email: "seller@example.de",
        ),
      ),
    ),
    (),
  )

  // 8. Outside XRechnung, EN 16931 only recommends electronic addresses:
  //    an invoice without them compiles, domestic or cross-border
  assert.eq(failed-rules(zugferd: "en16931"), ())
  assert.eq(
    failed-rules(zugferd: "en16931", recipient-overrides: (
      country: country.fr,
    )),
    (),
  )

  // 9. MINIMUM needs neither electronic addresses, buyer reference nor seller
  //    contact, but has no seller identifier (BT-29), so BR-CO-26 requires the
  //    seller VAT identifier (BT-31).
  assert.eq(failed-rules(zugferd: "minimum"), ())
  assert.eq(
    failed-rules(
      zugferd: "minimum",
      sender-overrides: (vat-id: none, tax-nr: "123/456/78901"),
    ),
    ("BR-CO-26",),
  )
}

// --- Test resolve-plural robustness and language behavior ---
#{
  import "/src/locale/lang/base.typ": base-language
  import "/src/locale/region/base.typ": base-region
  let de-res = locale.de-de(base-language, base-region).resolve-plural
  let en-res = locale.en-de(base-language, base-region).resolve-plural

  // 1. Any non-dict types (string, content, none, int) returned as-is
  assert.eq(de-res("Stück", 5), "Stück")
  assert.eq(de-res([Std.], 5), [Std.])
  assert.eq(de-res(none, 5), none)
  assert.eq(de-res(123, 5), 123)

  // 2. Singular vs Plural resolution
  let u-de = (singular: "Stunde", plural: "Stunden")
  assert.eq(de-res(u-de, 1), "Stunde")
  assert.eq(de-res(u-de, decimal("1")), "Stunde")
  assert.eq(de-res(u-de, 2), "Stunden")
  assert.eq(de-res(u-de, decimal("5.5")), "Stunden")
  assert.eq(de-res(u-de, 0), "Stunden")

  let u-en = (singular: "hour", plural: "hours")
  assert.eq(en-res(u-en, 1), "hour")
  assert.eq(en-res(u-en, 8), "hours")
  assert.eq(en-res(u-en, 0), "hours")

  // 3. Custom keys fallback to first pair
  let u-one-other = (one: "piece", other: "pieces")
  assert.eq(en-res(u-one-other, 1), "piece")
  assert.eq(en-res(u-one-other, 5), "piece") // falls back to first element "piece"

  // 5. Arbitrary custom dict fallback to first value
  let u-arbitrary = (customA: "first-val", customB: "second-val")
  assert.eq(de-res(u-arbitrary, 42), "first-val")

  // 6. Empty dictionary returns none
  assert.eq(de-res((:), 1), none)
}

// --- Argument checks and identifiers of the utilities ---
#import "/src/utils/types.typ"
#import "/src/utils/iban.typ": iban-valid, mod97
#import "/src/utils/creditor-id.typ": creditor-id-valid
#{
  // `types.require` builds its message only when the check fails, and the
  // message is the same as before
  types.require(5, "unit::value", none, int)
  types.require([content], "unit::value", str, content)
  assert.eq(
    catch(() => types.require(5, "unit::value", none, str)),
    "assertion failed: variable `unit::value`(5) must be of none | str",
  )
  assert.eq(
    catch(() => types.require("x", "unit::mode", "inclusive", "exclusive")),
    "assertion failed: variable `unit::mode`(\"x\") must be of \"inclusive\" | \"exclusive\"",
  )

  // ISO 7064 MOD 97-10 by code point: digits and letters A to Z
  assert.eq(mod97("123456"), calc.rem(123456, 97))
  assert.eq(mod97("A"), 10)
  assert.eq(mod97("Z9"), calc.rem(359, 97))
  assert(iban-valid("DE89370400440532013000"))
  assert(iban-valid("GB82WEST12345698765432"))
  assert(iban-valid("NL91ABNA0417164300"))
  assert(iban-valid("FR1420041010050500013M02606"))
  assert(not iban-valid("DE89370400440532013001"))
  assert(not iban-valid("GB82WEST1234569876543Z"))
  assert(not iban-valid("de89370400440532013000"))
  assert(creditor-id-valid("DE98ZZZ09999999999"))
  assert(not creditor-id-valid("DE99ZZZ09999999999"))
}
