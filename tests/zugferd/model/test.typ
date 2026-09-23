// The e-invoice data model built from a computed invoice: net amounts with
// gross prices, identifiers, texts, the placeholders of the visual invoice,
// electronic addresses, unit codes, payment data and the profile.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": (
  build-model, get-electronic-address, map-unit-code,
)
#import "/src/zugferd/profile.typ": resolve-profile, switch-profile
#import "/tests/data-test.typ": data-test, loom

#let seller = (
  name: "Seller GmbH",
  address: "Street 1",
  city: (name: "München", post-code: "80339"),
  country: country.de,
  tax-nr: "123/456/78901",
  vat-id: "DE123456789",
  contact: (
    name: "Max Mustermann",
    phone: "+49 89 1234567",
    email: "max@seller.de",
  ),
)
#let buyer = (
  name: "Buyer SAS",
  address: "Rue 1",
  city: (name: "Paris", post-code: "75001"),
  country: country.fr,
  vat-id: "FR99123456789",
)

/// Renders an invoice and calls `test` with the e-invoice data model built
/// from its children.
#let model-test(test, ..args, body) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "ignore",
  sender: seller,
  recipient: buyer,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(
    test: (ctx, data) => {
      let signal(kind) = loom.query.find-signal(data, kind)
      test(build-model(
        ctx,
        signal("line-items").item-data,
        payment-goal: signal("payment-goal"),
        bank: signal("bank-details"),
      ))
    },
    body,
  ),
)

#let sum(values) = values.fold(decimal("0"), (a, b) => a + b)

// --- 1. Gross prices are converted to net amounts that add up exactly ---
#model-test(tax-mode: "inclusive", model => {
  let lines = model.lines
  assert.eq(lines.map(l => l.name), ("Shirt", "Book", "Hat"))
  // 3 x 19.99 gross = 59.97 -> 50.39 net, +0.01 of the category rounding
  assert.eq(lines.map(l => l.net), (
    decimal("50.40"),
    decimal("11.21"),
    decimal("7.56"),
  ))
  assert.eq(lines.first().price, decimal("16.7983"))
  assert.eq(lines.at(2).allowances.map(a => a.amount), (decimal("0.84"),))
  assert.eq(
    model.allowance-charges.map(e => (e.category, e.rate, e.amount)),
    (
      ("S", decimal("0.19"), decimal("3.58")),
      ("S", decimal("0.07"), decimal("0.69")),
    ),
  )
  // Each VAT category adds up to its printed taxable amount
  for tax in model.taxes {
    let allowances = model
      .allowance-charges
      .filter(e => e.key == tax.key)
      .map(e => e.amount)
    assert.eq(
      sum(lines.filter(l => l.key == tax.key).map(l => l.net))
        - sum(allowances),
      tax.basis,
      message: "Lines of " + tax.key + " do not add up to " + str(tax.basis),
    )
  }
  assert.eq(model.totals.net, model.printed-totals.net)
  assert.eq(model.totals.gross, model.printed-totals.gross)
  assert.eq(model.totals.gross, decimal("75.97"))
})[
  #line-items[
    #item([Shirt], price: 19.99, quantity: 3)
    #item([Book], price: 12.00, quantity: 1, tax: tax.vat(7%))
    #item([Hat], price: 10.00, modifier: discount([Sale], amount: 10%))
    #discount([Coupon], amount: 5.00)
  ]
]

// --- 2. Prices, quantities, base quantities and credited lines ---
#model-test(model => {
  let (screws, consulting, paper, refund) = model.lines
  assert.eq(
    (screws.price, screws.quantity, screws.net),
    (
      decimal("0.1234"),
      decimal("1000"),
      decimal("123.40"),
    ),
  )
  assert.eq(consulting.quantity, decimal("0.125"))
  assert.eq(consulting.unit-code, "HUR")
  assert.eq(
    (paper.base-quantity, paper.net),
    (decimal("100"), decimal("12.48")),
  )
  // BR-27: the credited line has a positive price and a negative quantity
  assert.eq(
    (refund.price, refund.quantity, refund.net),
    (
      decimal("50"),
      decimal("-1"),
      decimal("-50"),
    ),
  )
  assert.eq(model.lines.map(l => l.id), ("1", "2", "3", "4"))
})[
  #line-items[
    #item([Screws], price: 0.1234, quantity: 1000)
    #item([Consulting], price: 95, quantity: 0.125, unit: unit.hour)
    #item([Paper], price: 4.99, quantity: 250, base-quantity: 100)
    #item([Refund], price: -50)
  ]
]

// --- 3. Placeholders of the visual invoice count as missing ---
#model-test(
  invoice-nr: none,
  recipient: (name: "Buyer SAS", country: country.fr),
  model => {
    assert.eq(model.invoice.number, none)
    assert.eq(model.buyer.address.city, none)
    assert.eq(model.buyer.address.post-code, none)
    assert.eq(model.buyer.address.lines, ())
    assert.eq(model.buyer.address.country, "FR")
  },
)[#line-items[#item([A], price: 1)]]

// --- 4. Parties: identifiers, VAT IDs and texts ---
#model-test(
  sender: seller
    + (
      name: ([*Seller*], "GmbH"),
      vat-id: "de 123 456 789",
      id: [SUP-1],
      global-id: (scheme: "0088", id: "4000001123452"),
    ),
  recipient: buyer + (global-id: "CUST-1"),
  model => {
    assert.eq(model.seller.name, "Seller, GmbH")
    assert.eq(model.seller.vat-id, "DE123456789")
    assert.eq(model.seller.id, "SUP-1")
    assert.eq(model.seller.global-id, (scheme: "0088", id: "4000001123452"))
    // A global ID without scheme is an ordinary identifier
    assert.eq(model.buyer.id, "CUST-1")
    assert.eq(model.buyer.global-id, none)
  },
)[#line-items[#item([A], price: 1)]]

// Not subject to VAT: no VAT identifiers (BR-O-02); the tax number identifies
// the seller (BT-29)
#model-test(tax: tax.outside-scope(), model => {
  assert.eq(model.outside-scope, true)
  assert.eq(model.seller.vat-id, none)
  assert.eq(model.seller.stated-vat-id, "DE123456789")
  assert.eq(model.buyer.vat-id, none)
  assert.eq(model.seller.id, "123/456/78901")
  assert.eq(model.buyer.electronic-address, none)
})[#line-items[#item([A], price: 1)]]

// --- 5. Intra-community supply: deliver to the buyer's country ---
#model-test(tax: tax.intra-community(), model => {
  assert.eq(model.ship-to.address.country, "FR")
  assert.eq(
    model.taxes.first().reason,
    "Steuerfreie innergemeinschaftliche Lieferung",
  )
})[#line-items[#item([A], price: 1)]]

#model-test(
  delivery-address: (name: "Dock", country: country.fr, location-id: "D-7"),
  model => {
    assert.eq(model.ship-to.name, "Dock")
    assert.eq(model.ship-to.id, "D-7")
  },
)[#line-items[#item([A], price: 1)]]

// --- 6. Payment: due date, terms, IBAN and BIC ---
#model-test(due-date: [sofort], model => {
  assert.eq(model.payment.due-date, datetime(year: 2026, month: 9, day: 15))
  assert.eq(model.payment.terms, "sofort")
  assert.eq(model.payment.means, (
    type-code: "58",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  ))
  assert.eq(model.payment.reference, "2026-01")
})[
  #line-items[#item([A], price: 1)]
  #payment-goal(days: 14)
  #bank-details(
    bank: "Musterbank",
    iban: "de75 5121 0800 1245 1261 99",
    bic: "soladest600",
  )
]

#model-test(due-date: datetime(year: 2026, month: 10, day: 1), model => {
  assert.eq(model.payment.due-date, datetime(year: 2026, month: 10, day: 1))
  assert.eq(model.payment.terms, "within 30 days")
  assert.eq(model.payment.means, none)
})[
  #line-items[#item([A], price: 1)]
  #payment-goal(date: [within 30 days])
]

// A payment goal without days or date is due at once, as printed
#model-test(model => {
  assert.eq(model.payment.due-date, none)
  assert.eq(model.payment.terms, "sofort nach Erhalt")
})[
  #line-items[#item([A], price: 1)]
  #payment-goal()
]

// --- 7. Electronic addresses (BT-34, BT-49) ---
#{
  let address(..party) = get-electronic-address(party.named())
  assert.eq(address(electronic-address: (scheme: "0088", id: "123")), (
    scheme: "0088",
    id: "123",
  ))
  assert.eq(address(electronic-address: "invoice@example.com"), (
    scheme: "EM",
    id: "invoice@example.com",
  ))
  // The VAT ID prefix selects the scheme of the issuing country
  assert.eq(address(vat-id: "FR99123456789"), (
    scheme: "9957",
    id: "FR99123456789",
  ))
  assert.eq(address(vat-id: "IT01234567890"), (
    scheme: "0211",
    id: "IT01234567890",
  ))
  assert.eq(address(vat-id: "EL123456789"), (scheme: "9933", id: "EL123456789"))
  assert.eq(address(vat-id: "ATU12345678", country: (code: "DE")), (
    scheme: "9914",
    id: "ATU12345678",
  ))
  // Without a scheme for the VAT ID, the email is used
  assert.eq(address(vat-id: "US123", contact: (email: "a@b.us")), (
    scheme: "EM",
    id: "a@b.us",
  ))
  // Not subject to VAT: the VAT ID is not used (BR-O-02)
  assert.eq(
    get-electronic-address(
      (vat-id: "DE123456789", email: "a@b.de"),
      is-outside-scope: true,
    ),
    (scheme: "EM", id: "a@b.de"),
  )
  assert.eq(address(vat-id: "DE123456789"), (
    scheme: "9930",
    id: "DE123456789",
  ))
  assert.eq(address(name: "No address"), none)
}

// --- 8. Unit codes (BT-130) ---
#{
  assert.eq(map-unit-code((display: "Std.", code: "HUR")), "HUR")
  assert.eq(map-unit-code((code: "MTK", name: "m²")), "MTK")
  assert.eq(map-unit-code("H87"), "H87")
  assert.eq(map-unit-code("hrs"), "HUR")
  assert.eq(map-unit-code([Std.]), "HUR")
  assert.eq(map-unit-code("Tage"), "DAY")
  // "St" (Stück) is the common abbreviation of pieces
  assert.eq(map-unit-code("St"), "H87")
  assert.eq(map-unit-code(none), "C62")
}

// --- 9. Profiles ---
#{
  // Explicit profiles are used as given, also between German parties
  let explicit = resolve-profile("en16931", "DE")
  assert.eq(
    (explicit.id, explicit.automatic, explicit.candidates),
    ("en16931", false, ("en16931",)),
  )
  assert.eq(resolve-profile("xrechnung", "FR").id, "xrechnung")
  assert.eq(resolve-profile("basic", "DE").id, "basic")

  // `auto`: XRechnung first for a buyer in Germany, EN 16931 otherwise
  let auto-de = resolve-profile(auto, "DE")
  assert.eq(
    (auto-de.id, auto-de.automatic, auto-de.candidates),
    ("xrechnung", true, ("xrechnung", "en16931")),
  )
  assert.eq(resolve-profile(auto, "FR").candidates, ("en16931",))
  assert.eq(resolve-profile(auto, none).candidates, ("en16931",))

  // Switching to the next candidate takes over its flags
  let switched = switch-profile(auto-de, "en16931")
  assert.eq(
    (switched.id, switched.name, switched.xrechnung, switched.automatic),
    ("en16931", "EN 16931 (COMFORT)", false, true),
  )
}
