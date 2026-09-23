// The validator collects every violated rule instead of stopping at the first
// one. A valid XRechnung model is built from a real invoice, then each check
// is triggered by changing the model.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/validate.typ": validate
#import "/tests/data-test.typ": data-test, loom

// Sorted rules of the diagnostics of `level`.
#let rules(model, level: "error") = (
  validate(model).filter(d => d.level == level).map(d => d.rule).sorted()
)

#let check(base) = {
  // --- The base invoice is valid ---
  assert.eq(validate(base), ())

  // Errors are listed before warnings, each with a rule, field and message.
  let m = base
  m.invoice.number = none
  m.payment.means.iban = "DE00512108001245126199"
  let diagnostics = validate(m)
  assert.eq(diagnostics.map(d => d.level), ("error", "warning"))
  assert.eq(diagnostics.first(), (
    level: "error",
    rule: "BR-02",
    field: "invoice-nr",
    message: "The invoice number (BT-1) is missing.",
    hint: "Set `invoice-nr` on the invoice.",
  ))

  // Several problems are reported together.
  let m = base
  m.invoice.number = none
  m.invoice.buyer-reference = none
  m.payment.means = none
  assert.eq(rules(m), ("BR-02", "BR-DE-1", "BR-DE-15"))

  // --- Document ---
  let m = base
  m.invoice.issue-date = none
  assert.eq(rules(m), ("BR-03",))
  let m = base
  m.currency = none
  assert.eq(rules(m), ("BR-05",))
  let m = base
  m.currency = "EURO"
  assert.eq(rules(m), ("BR-CL-04",))

  // --- Parties ---
  let m = base
  m.seller.name = none
  m.buyer.name = none
  assert.eq(rules(m), ("BR-06", "BR-07"))
  let m = base
  m.seller.address.country = none
  m.buyer.address.country = "UK"
  assert.eq(rules(m), ("BR-09", "BR-CL-14"))
  let m = base
  m.buyer.address.country = none
  assert.eq(rules(m), ("BR-11",))
  let m = base
  m.seller.vat-id = "123456789"
  assert.eq(rules(m), ("BR-CO-09",))

  // BR-CO-26: the tax number (as seller identifier) is enough, nothing is not
  let m = base
  m.seller.vat-id = none
  m.seller.id = "123/456/78901"
  assert.eq(rules(m), ())
  m.seller.id = none
  assert.eq(rules(m), ("BR-CO-26",))
  let m = base
  m.profile = resolve-profile("minimum", "DE")
  assert.eq(rules(m), ())
  m.seller.vat-id = none
  m.seller.id = "123/456/78901"
  assert.eq(rules(m), ("BR-CO-26",))

  // Electronic addresses: required by XRechnung, recommended by EN 16931
  let m = base
  m.seller.electronic-address = none
  m.buyer.electronic-address = none
  assert.eq(rules(m), ("PEPPOL-EN16931-R010", "PEPPOL-EN16931-R020"))
  m.profile = resolve-profile("en16931", "FR")
  m.invoice.buyer-reference = none
  assert.eq(rules(m), ())
  assert.eq(
    rules(m, level: "warning"),
    ("PEPPOL-EN16931-R010", "PEPPOL-EN16931-R020"),
  )
  m.profile = resolve-profile("basic", "FR")
  assert.eq(rules(m, level: "warning"), ())

  let m = base
  m.seller.electronic-address = (scheme: "XX", id: "1")
  m.buyer.electronic-address = (scheme: none, id: "1")
  m.seller.global-id = (scheme: "12", id: "1")
  assert.eq(rules(m), ("BR-63", "BR-CL-10", "BR-CL-25"))

  // XRechnung: seller contact, addresses and buyer reference
  let m = base
  m.seller.contact = none
  assert.eq(rules(m), ("BR-DE-2",))
  let m = base
  m.seller.contact.name = none
  m.seller.contact.phone = none
  m.seller.contact.email = none
  assert.eq(rules(m), ("BR-DE-5", "BR-DE-6", "BR-DE-7"))
  // BR-DE-27 and BR-DE-28 are errors (Mustang rejects the invoice), with the
  // official e-mail syntax of XRechnung (XR-EMAIL-REGEX)
  let m = base
  m.seller.contact.phone = "12"
  m.seller.contact.email = "seller.example.de"
  assert.eq(rules(m), ("BR-DE-27", "BR-DE-28"))
  assert.eq(rules(m, level: "warning"), ())
  for email in (
    "info@müller-bau.de",
    ".max@seller.de",
    "max@seller",
    "a@b@c.de",
  ) {
    m.seller.contact.email = email
    assert.eq(rules(m), ("BR-DE-27", "BR-DE-28"), message: email)
  }
  m.seller.contact.phone = "(089) 12"
  for email in ("info@xn--mller-bau-q9a.de", "max.m+rechnung@seller-gmbh.de") {
    m.seller.contact.email = email
    assert.eq(rules(m), (), message: email)
  }
  let m = base
  m.seller.address.city = none
  m.seller.address.post-code = none
  m.buyer.address.city = none
  m.buyer.address.post-code = none
  assert.eq(rules(m), ("BR-DE-3", "BR-DE-4", "BR-DE-8", "BR-DE-9"))
  let m = base
  m.ship-to = (
    name: "Dock",
    id: none,
    global-id: none,
    address: (
      lines: (),
      city: none,
      post-code: none,
      state: none,
      country: "DE",
    ),
  )
  assert.eq(rules(m), ("BR-DE-10", "BR-DE-11"))
  m.ship-to.address.country = none
  assert.eq(rules(m), ("BR-57", "BR-DE-10", "BR-DE-11"))

  // --- Lines ---
  let m = base
  m.lines.at(0).name = none
  m.lines.at(0).unit-code = "HOURS"
  assert.eq(rules(m), ("BR-25", "BR-CL-23"))
  let m = base
  m.lines.at(0).category = none
  assert.eq(rules(m), ("BR-CO-04",))
  let m = base
  m.lines = ()
  assert("BR-16" in rules(m))

  // --- VAT ---
  let tax(category, rate: 0, reason: none) = (
    base.taxes.first()
      + (
        category: category,
        rate: decimal(rate),
        reason: reason,
        amount: calc.round(base.taxes.first().basis * decimal(rate), digits: 2),
      )
  )
  let with-tax(model, ..taxes) = {
    let model = model
    model.taxes = taxes.pos()
    // The lines have the category of the (first) VAT group, as in an invoice.
    for i in range(model.lines.len()) {
      model.lines.at(i).category = model.taxes.first().category
    }
    model
  }
  assert.eq(rules(with-tax(base, tax("AA", rate: "0.07"))), ("BR-CL-18",))
  assert.eq(rules(with-tax(base, tax("B", rate: "0.22"))), ("BR-CL-18",))
  assert.eq(rules(with-tax(base, tax("S"))), ("BR-S-05",))
  assert.eq(rules(with-tax(base, tax("L"))), ("BR-AF-05",))
  assert.eq(rules(with-tax(base, tax("E", rate: "0.19", reason: "x"))), (
    "BR-E-05",
  ))
  assert.eq(rules(with-tax(base, tax("E"))), ("BR-E-10",))
  assert.eq(rules(with-tax(base, tax("E", reason: "§ 4 Nr. 21 UStG"))), ())

  let m = base
  m.seller.vat-id = none
  m.seller.tax-nr = none
  m.seller.id = "SUP-1"
  assert.eq(rules(m), ("BR-S-02",))
  assert.eq(rules(with-tax(m, tax("Z"))), ("BR-Z-02",))
  assert.eq(rules(with-tax(m, tax("O", reason: "x"))), ())

  let m = base
  m.seller.vat-id = none
  m.seller.id = "123/456/78901"
  m.buyer.vat-id = none
  assert.eq(rules(with-tax(m, tax("K", reason: "x"))), (
    "BR-IC-02",
    "BR-IC-02",
    "BR-IC-12",
  ))
  assert.eq(rules(with-tax(m, tax("G", reason: "x"))), ("BR-G-02",))
  assert.eq(rules(with-tax(m, tax("AE", reason: "x"))), ("BR-AE-02",))
  let other-s = (
    tax("S", rate: "0.19")
      + (key: "S-2", basis: decimal("0"), amount: decimal("0"))
  )
  assert.eq(
    rules(with-tax(base, tax("O", reason: "x"), other-s)),
    ("BR-O-11",),
  )

  // --- Payment ---
  let m = base
  m.payment.due-date = none
  assert.eq(rules(m), ("BR-CO-25",))
  m.payment.terms = "sofort"
  assert.eq(rules(m), ())
  let m = base
  m.payment.means = none
  assert.eq(rules(m), ("BR-DE-1",))
  m.profile = resolve-profile("en16931", "FR")
  assert.eq(rules(m), ())
  let m = base
  m.payment.means.iban = "DE00512108001245126199"
  m.totals.prepaid = m.totals.gross + 1
  m.totals.due = decimal("-1")
  assert.eq(rules(m), ())
  assert.eq(rules(m, level: "warning"), ("BR-CO-16", "BR-DE-19"))

  // --- Consistency with the printed invoice ---
  let m = base
  m.printed-totals.gross += decimal("0.01")
  assert.eq(rules(m), ("BR-CO-15",))
  let m = base
  m.lines.at(0).net += decimal("0.01")
  assert.eq(rules(m), ("BR-S-08",))
  let m = base
  m.taxes.at(0).basis += decimal("0.01")
  assert.eq(rules(m), ("BR-CO-13", "BR-S-08"))
}

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
  sender: (
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
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    email: "accounting@buyer.de",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#data-test(test: (ctx, data) => {
  let signal(kind) = loom.query.find-signal(data, kind)
  let model = build-model(
    ctx,
    signal("line-items").item-data,
    payment-goal: signal("payment-goal"),
    bank: signal("bank-details"),
  )
  assert.eq(model.profile.id, "xrechnung")
  check(model)
})[
  #line-items[
    #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
  ]
  #payment-goal(days: 14)
  #bank-details(
    bank: "Musterbank",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )
]
