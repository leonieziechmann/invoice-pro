// The invariants that the e-invoice states what the invoice prints
// (src/zugferd/rules/equivalence.typ): IP-PRINT-01, IP-CALC-01, IP-CALC-02,
// and PEPPOL-EN16931-R120 of XRechnung. A computed invoice keeps them; a
// model or a computed invoice changed after the computation breaks them.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/src/zugferd/rules/equivalence.typ": findings
#import "/src/zugferd/rules/engine.typ": diagnostics
#import "/src/zugferd/zugferd.typ": process-zugferd
#import "/tests/zugferd/harness.typ": bank, buyer-de, payment-means, seller
#import "/tests/data-test.typ": data-test, loom

/// Renders an invoice and calls `test` with its model, its computed items
/// (`item-data`) and the totals it prints, and the data the root context
/// gives the e-invoice.
#let invariant-test(test, ..args, body) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "ignore",
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(
    test: (ctx, data) => {
      let signal(kind) = loom.query.find-signal(data, kind)
      let items = signal("line-items")
      let inputs = (
        payment-goal: signal("payment-goal"),
        bank: signal("bank-details"),
        payment-means: payment-means(data),
      )
      test(
        build-model(ctx, items.item-data, ..inputs),
        items.item-data,
        items.total,
        (ctx: ctx, inputs: inputs),
      )
    },
    body,
  ),
)

/// (rule, term) of every finding, the field for a finding without a term.
#let found(model, item-data, printed) = findings(
  model,
  item-data,
  printed,
).map(f => (f.key, f.at("term", default: f.field)))

/// The rules of the findings, each once.
#let rules(model, item-data, printed) = {
  findings(model, item-data, printed).map(f => f.key).dedup()
}

#let one = decimal("1")

// Lines with a discount and a surcharge of their own, two VAT rates, a
// negative price (BR-27: a positive price of a negative quantity), a
// document level discount and surcharge, split by VAT rate, and a
// prepayment.
#let rich = [
  #line-items[
    #item(
      [Beratung],
      price: 120,
      quantity: 3,
      unit: unit.hour,
      modifier: discount([Stammkunde], amount: 10%),
    )
    #item(
      [Buch],
      price: 24.95,
      quantity: 2,
      tax: tax.vat(7%),
      modifier: surcharge([Porto], amount: 2.50),
    )
    #item([Gutschrift], price: -15, quantity: 1)
    #discount([Projektrabatt], amount: 3%)
    #surcharge([Reisekosten], amount: 50)
    #prepayment(100, name: "Abschlag")
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 1. A computed invoice keeps the invariants ---
#invariant-test((model, item-data, printed, _) => {
  assert.eq(found(model, item-data, printed), ())
  assert.eq(model.lines.at(2).quantity, -one)
  assert.eq(model.lines.at(2).price, decimal("15"))
})[#rich]

#invariant-test(tax-mode: "inclusive", (model, item-data, printed, _) => {
  assert.eq(found(model, item-data, printed), ())
  // The net amounts are those of the gross amounts, within the rounding.
  assert(model.lines.first().net != item-data.items.first().total)
})[#rich]

// --- 2. IP-PRINT-01: the model differs from what the invoice prints ---
#invariant-test((model, item-data, printed, _) => {
  let check(m, expected) = assert.eq(found(m, item-data, printed), expected)

  // A line: its quantity, price, base quantity, net amount, allowances and
  // charges.
  let m = model
  m.lines.at(0).quantity = decimal("4")
  check(m, (("IP-PRINT-01", "invoiced quantity (BT-129)"),))
  let m = model
  m.lines.at(0).price = decimal("121")
  check(m, (("IP-PRINT-01", "item net price (BT-146)"),))
  let m = model
  m.lines.at(0).base-quantity = decimal("10")
  check(m, (("IP-PRINT-01", "price base quantity (BT-149)"),))
  let m = model
  m.lines.at(1).net += one
  check(m, (("IP-PRINT-01", "line net amount (BT-131)"),))
  let m = model
  m.lines.at(0).allowances.at(0).amount += one
  check(m, (("IP-PRINT-01", "line allowance amount (BT-136)"),))
  let m = model
  m.lines.at(1).charges.at(0).amount += one
  check(m, (("IP-PRINT-01", "line charge amount (BT-141)"),))
  let m = model
  m.lines.at(0).allowances = ()
  check(m, (
    (
      "IP-PRINT-01",
      "number of allowances and charges of the line (BG-27, BG-28)",
    ),
  ))
  // A negative price as a positive price of a positive quantity: the sign
  // is lost (BR-27 states it as a positive price of a negative quantity).
  let m = model
  m.lines.at(2).quantity = one
  check(m, (("IP-PRINT-01", "invoiced quantity (BT-129)"),))
  // As printed, the line states what the invoice prints (BR-27 is the
  // validator's).
  let m = model
  m.lines.at(2).price = decimal("-15")
  m.lines.at(2).quantity = one
  check(m, ())
  let m = model
  let _ = m.lines.pop()
  check(m, (("IP-PRINT-01", "number of invoice lines (BG-25)"),))

  // A document level allowance or charge, and their number.
  let m = model
  m.allowance-charges.at(0).amount += one
  check(m, (("IP-PRINT-01", "document level allowance amount (BT-92)"),))
  let m = model
  m.allowance-charges.at(-1).charge = false
  check(m, (("IP-PRINT-01", "document level charge amount (BT-99)"),))
  let m = model
  m.allowance-charges.push(model.allowance-charges.first())
  check(m, (
    (
      "IP-PRINT-01",
      "number of document level allowances and charges (BG-20, BG-21)",
    ),
  ))

  // A VAT group.
  let m = model
  m.taxes.at(0).basis += one
  check(m, (("IP-PRINT-01", "VAT category taxable amount (BT-116)"),))
  let m = model
  m.taxes.at(0).amount += one
  check(m, (("IP-PRINT-01", "VAT category tax amount (BT-117)"),))
  let m = model
  m.taxes.at(0).rate = decimal("0.2")
  check(m, (("IP-PRINT-01", "VAT category rate (BT-119)"),))
  let m = model
  m.taxes.at(0).category = "Z"
  check(m, (("IP-PRINT-01", "VAT category code (BT-118)"),))
  let m = model
  let _ = m.taxes.pop()
  check(m, (("IP-PRINT-01", "number of VAT breakdowns (BG-23)"),))

  // The totals.
  for (key, term) in (
    ("net", "invoice total amount without VAT (BT-109)"),
    ("tax", "invoice total VAT amount (BT-110)"),
    ("gross", "invoice total amount with VAT (BT-112)"),
    ("prepaid", "paid amount (BT-113)"),
    ("due", "amount due for payment (BT-115)"),
  ) {
    let m = model
    m.totals.at(key) += one
    check(m, (("IP-PRINT-01", term),))
  }
  let m = model
  m.totals.line += one
  check(m, (
    (
      "IP-PRINT-01",
      "sum of the line net amounts (BT-106) minus the allowances (BT-107) plus the charges (BT-108)",
    ),
  ))
  // The totals the invoice prints (`ctx.global.total`).
  assert.eq(
    found(model, item-data, printed + (net: printed.net + one)).map(f => f.at(
      1,
    )),
    (
      "invoice total amount without VAT (BT-109)",
      "invoice total VAT amount (BT-110)",
      "sum of the line net amounts (BT-106) minus the allowances (BT-107) plus the charges (BT-108)",
    ),
  )

  // Every finding is an error with a message and a hint.
  let m = model
  m.lines.at(1).net += one
  let d = diagnostics(findings(m, item-data, printed)).first()
  assert.eq(d.rule, "IP-PRINT-01")
  assert.eq(d.level, "error")
  assert.eq(d.field, "item 2 (Buch)")
  assert(d.message.contains("line net amount (BT-131)"))
  assert(d.hint != none)
})[#rich]

// With gross prices, a net amount differs by more than the rounding allows.
#invariant-test(tax-mode: "inclusive", (model, item-data, printed, _) => {
  let m = model
  m.lines.at(1).net += decimal("0.05")
  let f = findings(m, item-data, printed)
  assert.eq(f.map(f => (f.key, f.term)), (
    ("IP-PRINT-01", "line net amount (BT-131)"),
  ))
  // The message compares the net amount with VAT to the printed gross one.
  assert.eq(f.first().rate, decimal("0.07"))
  assert(diagnostics(f).first().message.contains("7"))
  // Within the rounding: a cent less.
  let m = model
  m.lines.at(1).net -= decimal("0.001")
  assert.eq(found(m, item-data, printed), ())
})[#rich]

// --- 3. IP-CALC-01 and IP-CALC-02: the printed amounts add up ---
#invariant-test((model, item-data, printed, _) => {
  // A part of the document level discount per VAT rate that does not add up
  // to the discount.
  let data = item-data
  let key = data.discounts.first().split.keys().first()
  data.discounts.at(0).split.at(key).absolute -= decimal("0.01")
  let calc01 = findings(model, data, printed).filter(f => f.key == "IP-CALC-01")
  assert.eq(calc01.map(f => (f.field, f.amount - f.parts)), (
    ("discount (Projektrabatt)", decimal("0.01")),
  ))
  assert(diagnostics(calc01).first().message.contains("add up to"))

  // A taxable amount the lines, allowances and charges of its VAT group do
  // not add up to.
  let data = item-data
  data.taxes.at(key).basis += one
  let calc02 = findings(model, data, printed).filter(f => f.key == "IP-CALC-02")
  assert.eq(calc02.len(), 1)
  assert.eq(calc02.first().expected - calc02.first().sum, one)
  assert(diagnostics(calc02).first().message.contains("taxable amount"))
})[#rich]

// A discount on a VAT group whose lines add up to a credit is a charge of
// that group, with the sign of its part: nothing to report.
#invariant-test((model, item-data, printed, _) => {
  assert.eq(found(model, item-data, printed), ())
  let parts = model.allowance-charges.map(e => (e.charge, e.rate))
  assert.eq(parts, ((false, decimal("0.19")), (true, decimal("0.07"))))
})[
  #line-items[
    #item([Beratung], price: 100, quantity: 1)
    #item([Gutschrift], price: -40, quantity: 2, tax: tax.vat(7%))
    #discount([Treuerabatt], amount: 3%)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 4. PEPPOL-EN16931-R120 (XRechnung): the quantity times the price is
// the line's net amount, within 0.02; 100.40 yen round to whole yen ---
#let yen = [
  #line-items[#item([Leistung], price: 100.4, quantity: 1)]
  #payment-goal(days: 14)
  #bank
]
#invariant-test(
  zugferd: "xrechnung",
  currency: "JPY",
  (model, item-data, printed, root) => {
    let f = findings(model, item-data, printed)
    assert.eq(f.map(f => (f.key, f.field)), (
      ("PEPPOL-EN16931-R120", "item 1 (Leistung)"),
    ))
    assert.eq(f.first().net, decimal("100"))
    assert.eq(f.first().expected, decimal("100.4"))
    // A warning, as KoSIT reports it; not an EN 16931 rule.
    let ctx = root.ctx + (global: (total: printed))
    let result = process-zugferd(ctx, item-data, ..root.inputs)
    let r120 = result.diagnostics.filter(d => (
      d.rule == "PEPPOL-EN16931-R120"
    ))
    assert.eq(r120.map(d => d.level), ("warning",))
    let m = model
    m.profile.xrechnung = false
    assert.eq(found(m, item-data, printed), ())
  },
)[#yen]

// Whole yen keep it; so does a line with an allowance of its own in cents.
#invariant-test(
  zugferd: "xrechnung",
  currency: "JPY",
  (model, item-data, printed, _) => {
    assert.eq(found(model, item-data, printed), ())
  },
)[
  #line-items[#item([Leistung], price: 100, quantity: 3)]
  #payment-goal(days: 14)
  #bank
]
#invariant-test(zugferd: "xrechnung", (model, item-data, printed, _) => {
  assert.eq(found(model, item-data, printed), ())
  // A net amount 0.03 off is beyond it.
  let m = model
  m.lines.at(0).net += decimal("0.03")
  assert.eq(rules(m, item-data, printed), (
    "IP-PRINT-01",
    "PEPPOL-EN16931-R120",
  ))
})[
  #line-items[
    #item(
      [Wartung],
      price: 33.33,
      quantity: 7,
      modifier: discount([Rabatt], amount: 3%),
    )
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 5. Gross prices: the cents the rounded net amounts of a VAT group
// exceed go to the lines rounded furthest up, a line of 0.01 (0.0084 net)
// included, which turns to 0; they do not pile up on the one line that
// stays above 0 (83.99 for 100.00 including 19 % VAT, 0.04 off) ---
#invariant-test(
  zugferd: "xrechnung",
  tax-mode: "inclusive",
  (model, item-data, printed, _) => {
    assert.eq(found(model, item-data, printed), ())
    let divisor = decimal("1.19")
    for (line, item) in model.lines.zip(item-data.items) {
      assert(
        calc.abs(line.net - item.total / divisor) < decimal("0.01"),
        message: "line " + line.id + ": " + str(line.net),
      )
    }
    assert.eq(model.lines.first().net, decimal("84.03"))
    let zero = model.lines.filter(line => line.net == decimal("0"))
    assert.eq(zero.len(), 4)
    // The lines add up to the printed taxable amount.
    let sum = model.lines.map(line => line.net).sum()
    assert.eq(sum, model.taxes.first().basis)
  },
)[
  #line-items[
    #item([Gerät], price: 100, quantity: 1)
    #for i in range(30) { item([Kleinteil #(i + 1)], price: 0.01) }
  ]
  #payment-goal(days: 14)
  #bank
]
