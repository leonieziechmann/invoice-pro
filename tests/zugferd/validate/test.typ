// The validator collects every violated rule instead of stopping at the first
// one. A valid XRechnung model is built from a real invoice, then each check
// is triggered by changing the model.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/rules/engine.typ": run-rules
#import "/tests/data-test.typ": data-test, loom
// `run-rules`, checking that the registry lists each rule for the profile.
#import "/tests/zugferd/harness.typ": diagnostics as checked

// Sorted rules of the diagnostics of `level`.
#let rules(model, level: "error") = (
  checked(model).filter(d => d.level == level).map(d => d.rule).sorted()
)

#let check(base) = {
  // --- The base invoice is valid ---
  assert.eq(run-rules(base), ())

  // Errors are listed before warnings, each with a rule, field and message.
  let m = base
  m.invoice.number = none
  m.totals.prepaid = m.totals.gross + 1
  m.totals.due = decimal("-1")
  let diagnostics = run-rules(m)
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
  m.payment.means = ()
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

  // Electronic addresses: required by XRechnung (the Peppol rules), which
  // EN 16931 leaves optional and does not check: a warning of invoice-pro's
  // own there (IP-EADDR-01)
  let m = base
  m.seller.electronic-address = none
  m.buyer.electronic-address = none
  assert.eq(rules(m), ("PEPPOL-EN16931-R010", "PEPPOL-EN16931-R020"))
  m.profile = resolve-profile("en16931", "FR")
  m.invoice.buyer-reference = none
  assert.eq(rules(m), ())
  assert.eq(rules(m, level: "warning"), ("IP-EADDR-01", "IP-EADDR-01"))
  let found = checked(m)
  assert.eq(found.map(d => d.field).sorted(), ("recipient", "sender"))
  let seller = found.find(d => d.field == "sender")
  assert.eq(seller.message, "The seller electronic address (BT-34) is missing.")
  assert(
    seller.hint.starts-with(
      "EN 16931 leaves it optional, but a delivery over Peppol requires it, as XRechnung does. ",
    ),
    message: seller.hint,
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
  // The split payment of Italy (B): a domestic Italian invoice (BR-B-01)
  // without standard rated items (BR-B-02)
  let split = with-tax(base, tax("B", rate: "0.22"))
  assert.eq(rules(split), ("BR-B-01",))
  let d = checked(split).first()
  assert.eq(d.field, "sender.country")
  assert.eq(
    d.message,
    "The split payment (B) is for domestic Italian invoices, but the seller country code (BT-40) is \"DE\".",
  )
  let italian = split
  italian.seller.address.country = "IT"
  italian.buyer.address.country = "IT"
  assert.eq(rules(italian), ())
  // (a standard rated VAT group next to it, whatever else it breaks)
  italian.taxes.push(tax("S", rate: "0.22"))
  let d = checked(italian).find(d => d.rule == "BR-B-02")
  assert.ne(d, none, message: repr(rules(italian)))
  assert.eq(d.field, "tax")
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
  m.payment.means = ()
  assert.eq(rules(m), ("BR-DE-1",))
  m.profile = resolve-profile("en16931", "FR")
  assert.eq(rules(m), ())
  // An invalid IBAN is an error: the buyer could not pay (XRechnung: BR-DE-19
  // for a SEPA credit transfer)
  let m = base
  m.payment.means.at(0).iban = "DE00512108001245126199"
  assert.eq(rules(m), ("BR-DE-19",))
  m.profile = resolve-profile("en16931", "FR")
  assert.eq(rules(m), ("IP-PAY-01",))
  // Prepayments above the total: BR-CO-16 holds (the amount due is the total
  // minus the prepaid amount), but it is negative (IP-PREPAID-01)
  let m = base
  m.totals.prepaid = m.totals.gross + 1
  m.totals.due = decimal("-1")
  assert.eq(rules(m), ())
  assert.eq(rules(m, level: "warning"), ("IP-PREPAID-01",))

  // --- Consistency with the printed invoice (IP-PRINT-01) and in itself ---
  let m = base
  m.printed-totals.gross += decimal("0.01")
  assert.eq(rules(m), ("IP-PRINT-01",))
  let d = checked(m).first()
  assert.eq(d.field, "line-items")
  assert(
    d.message.starts-with("The e-invoice states the total with VAT (BT-112) "),
    message: d.message,
  )
  let m = base
  m.lines.at(0).net += decimal("0.01")
  assert.eq(rules(m), ("BR-S-08",))
  let m = base
  m.taxes.at(0).basis += decimal("0.01")
  assert.eq(rules(m), ("BR-S-08", "IP-PRINT-01"))

  // --- BR-48: a VAT breakdown without rate names its VAT group, which the
  // write guard can only name by the element of the XML ---
  let m = base
  m.taxes.at(0).rate = none
  assert.eq(rules(m), ("BR-48",))
  let d = run-rules(m).first()
  assert.eq(d.field, "tax S (no rate)")
  assert.eq(
    d.message,
    "The VAT group of the category \"S\" has no VAT category rate (BT-119), which every VAT breakdown but one not subject to VAT (O) has.",
  )
  // Not subject to VAT (O): it has no rate.
  assert.eq(rules(with-tax(base, tax("O", reason: "x") + (rate: none))), ())
}

// --- The rule registry: every finding of a check has an entry and a
// message, and a diagnostic takes its level and id from the entry ---
#import "/src/zugferd/rules/engine.typ": diagnostics, rule-registry
#import "/src/zugferd/rules/messages.typ": messages
#import "/src/zugferd/rules/xrechnung-messages.typ": (
  messages as xrechnung-messages,
)
#{
  let registry = rule-registry()
  // The rules of the write guard (IP-GUARD-*) build their messages in
  // guard/report.typ. Every other rule has one message, in messages.typ or,
  // for a rule of XRechnung that no other profile reports (BR-DE-*), in
  // xrechnung-messages.typ, which `diagnostics` loads for such a rule.
  assert.eq(
    registry.keys().filter(key => not key.starts-with("IP-GUARD-")).sorted(),
    (messages.keys() + xrechnung-messages.keys()).sorted(),
  )
  for key in xrechnung-messages.keys() {
    assert(key.starts-with("BR-DE-"), message: key)
    assert(key not in messages, message: key)
    assert.eq(registry.at(key).profiles, ("xrechnung",), message: key)
  }
  // `profiles` lists the profiles in which a check can report its rule:
  // EN 16931 and XRechnung state every input IP-PROFILE-01 looks for.
  assert.eq(registry.at("IP-PROFILE-01").profiles, (
    "minimum",
    "basic-wl",
    "basic",
  ))
  let missing = (key: "BR-02", field: "invoice-nr")
  let negative = (
    key: "IP-DOC-04",
    field: "line-items",
    code: "380",
    gross: decimal("-1"),
  )
  // The level of the entry, errors first.
  assert.eq(diagnostics((negative, missing)), (
    (
      level: "error",
      rule: "BR-02",
      field: "invoice-nr",
      message: "The invoice number (BT-1) is missing.",
      hint: "Set `invoice-nr` on the invoice.",
    ),
    (
      level: "warning",
      rule: "IP-DOC-04",
      field: "line-items",
      message: diagnostics((negative,)).first().message,
      hint: diagnostics((negative,)).first().hint,
    ),
  ))
  // The id and the level a finding names, among those of its entry.
  let rate = (
    key: "vat-rate-zero",
    id: "BR-E-05",
    field: "tax E 19%",
    category: "E",
  )
  assert.eq(diagnostics((rate,)).first().rule, "BR-E-05")
  let period = (
    key: "IP-PERIOD-01",
    level: "warning",
    field: "references",
    printed: "June 2026",
    stated: "01.06.2026 - 30.06.2026",
    source: none,
    term: "BG-14",
    contradicts: false,
    document: none,
  )
  assert.eq(diagnostics((period,)).first().level, "warning")
  assert.eq(
    diagnostics((period + (level: "error", contradicts: true),)).first().level,
    "error",
  )
  // Anything else stops the compilation: every diagnostic is in the registry.
  let fails(finding, expected) = {
    let message = catch(() => diagnostics((finding,)))
    assert(
      message != none and message.contains(expected),
      message: "Expected `" + expected + "`, got " + repr(message),
    )
  }
  fails(
    (key: "BR-99", field: "x"),
    "invoice-pro: the rule BR-99 is not in the rule registry",
  )
  fails(
    rate + (id: "BR-S-05"),
    "invoice-pro: the rule registry has no error BR-S-05 for the entry vat-rate-zero",
  )
  fails(
    missing + (level: "warning"),
    "invoice-pro: the rule registry has no warning BR-02 for the entry BR-02",
  )
  // XRechnung requires the electronic addresses: a warning is IP-EADDR-01
  fails(
    (
      key: "PEPPOL-EN16931-R020",
      level: "warning",
      field: "sender",
      term: "seller electronic address (BT-34)",
      vat-id: none,
      represented: false,
      reference: none,
    ),
    "invoice-pro: the rule registry has no warning PEPPOL-EN16931-R020 for the entry PEPPOL-EN16931-R020",
  )
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
