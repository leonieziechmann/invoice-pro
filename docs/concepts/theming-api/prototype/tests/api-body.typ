// api-body checks: totals row model (view.totals), items-table knobs, bank
// reference, payment sentence. --input case=excl|incl|plain|noref|style|keep|rule|inset
// Every assertion runs inside a part wrap, i.e. on the real view of the component.
#import "/src/lib.typ": *

#let case = sys.inputs.at("case", default: "excl")
#let has(c, s) = repr(c).contains(s)
#let kinds(v) = v.totals.rows.map(r => r.kind)

#let check-totals(ctx, view, inner) = {
  let k = kinds(view)
  let tax-rates = view.totals.rows.filter(r => r.kind == "tax").map(r => r.rate)
  if case == "excl" {
    assert.eq(k, (
      "subtotal",
      "discount",
      "surcharge",
      "net-total",
      "tax",
      "tax",
      "total",
      "prepayment",
      "amount-due",
    ))
    // 0 % (exempt) is removed in measure; the v1 taxes still carry it for the notes
    assert(view.taxes.len() == 3, message: "v1 taxes keep the 0 % group")
    assert(
      tax-rates.len() == 2
        and not tax-rates.any(r => has(r, "0 %") or has(r, "0%")),
      message: repr(tax-rates),
    )
    let due = view.totals.rows.last()
    assert(due.payable and view.totals.payable.kind == "amount-due")
    let total = view.totals.rows.find(r => r.kind == "total")
    assert(not total.payable)
    assert.eq(due.value.value, total.value.value - decimal("500"))
    assert.eq(
      view.totals.rows.find(r => r.kind == "prepayment").value.value,
      decimal("-500"),
    )
    assert.eq(view.totals.rows.at(1).value.value < 0, true) // discounts are negative
    assert(
      view.totals.rows.at(1).rate != none,
      message: "relative discount carries its signed rate",
    )
    assert(
      view.totals.rows.at(2).rate == none,
      message: "absolute surcharge carries no rate",
    )
    assert.eq(view.totals.rows.at(3).emphasis, "strong")
    assert.eq(total.emphasis, "total")
    // the tax marker of a rate with grounds sits in the complete label; no trailing colons
    assert(view.totals.rows.all(r => not repr(r.label).ends-with(":\")")))
  } else if case == "incl" {
    assert.eq(k, (
      "subtotal",
      "discount",
      "total",
      "tax",
      "tax",
      "prepayment",
      "amount-due",
    ))
    assert(view.totals.payable.kind == "amount-due")
    assert.eq(
      view.totals.payable.value.value,
      view.totals.rows.find(r => r.kind == "total").value.value
        - decimal("100"),
    )
  } else if case in ("plain", "noref", "style", "rule", "inset") {
    assert.eq(k, ("net-total", "tax", "total"))
    assert(
      view.totals.payable.kind == "total" and view.totals.rows.last().payable,
    )
  }
  let out = inner(ctx, view)
  // the default renderer prints every row label
  if case == "excl" {
    assert(
      has(out, "Fälliger Betrag")
        and has(out, "Anzahlung")
        and has(out, "Abschlag"),
    )
  }
  out
}

#let check-payment(ctx, view, inner) = {
  let out = inner(ctx, view)
  if case in ("excl", "incl") {
    assert.eq(view.amount-kind, "amount-due")
    assert(
      has(out, "fälligen Betrag") and not has(out, "Gesamtbetrag"),
      message: repr(out),
    )
  } else {
    assert.eq(view.amount-kind, "total")
    assert(has(out, "Gesamtbetrag"), message: repr(out))
  }
  out
}

#let check-bank(ctx, view, inner) = {
  assert.eq(view.iban.value, "DE75512108001245126199")
  assert.eq(
    view.iban.text,
    "DE75\u{a0}5121\u{a0}0800\u{a0}1245\u{a0}1261\u{a0}99",
  )
  let out = inner(ctx, view)
  assert(
    has(out, "DE75\u{a0}5121"),
    message: "the default renderer prints the grouped IBAN",
  )
  if case == "noref" {
    assert(
      not has(out, "Verwendungszweck"),
      message: "show-reference: false hides the reference",
    )
  } else {
    assert.eq(view.payment-reference, "2026-0142")
    assert(
      has(out, "Verwendungszweck") and has(out, "2026-0142"),
      message: "the default renderer prints the reference",
    )
  }
  out
}

// keep-together: every item's name and description land on the same page
#let check-keep(ctx, view, inner) = {
  inner(ctx, view)
  context {
    let names = query(<kt-name>)
    let descs = query(<kt-desc>)
    assert(names.len() == descs.len() and names.len() > 0)
    for (n, d) in names.zip(descs) {
      assert(
        n.location().page() == d.location().page(),
        message: "item "
          + str(n.value)
          + " split from its description (p"
          + str(n.location().page())
          + " / p"
          + str(d.location().page())
          + ")",
      )
    }
    assert(
      counter(page).final().first() >= 2,
      message: "the keep fixture must break across pages",
    )
  }
}

#let knobs = if case == "style" {
  import theme.custom: *
  items-table(header-style: (
    fill: rgb("#b00020"),
    style: "italic",
    size: t => t.sizes.body * 1.1,
  ))
  totals(fill: rgb("#1f2937"), min-width: 120mm, width: 30%)
} else if case == "rule" {
  theme.custom.items-table(row-rule: t => t.strokes.hairline + t.colors.border)
} else if case == "inset" {
  theme.custom.items-table(row-inset: 6pt)
}

#let th = theme.classic.with(
  theme.custom.wrap("totals", check-totals),
  theme.custom.wrap("payment-terms", check-payment),
  theme.custom.wrap("bank-details", check-bank),
  if case == "keep" { theme.custom.wrap("items-table", check-keep) },
  knobs,
)

// resolved options (derivations inside header-style resolve against the tokens)
#if case == "style" {
  let r = theme.resolve(th)
  assert.eq(r.options.items-table.header-style, (
    fill: rgb("#b00020"),
    style: "italic",
    size: 11pt,
  ))
  assert.eq(r.options.totals.min-width, 120mm)
  assert.eq(r.options.totals.color, auto)
}
#if case == "rule" {
  assert.eq(theme.resolve(th).options.items-table.row-rule, 0.25pt + black)
}

#show: invoice.with(
  theme: th,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "2026-0142",
)

#if case == "excl" [
  #line-items[
    #item([Beratung], price: 1000, tax: tax.vat(19%))
    #item([Fachbuch], price: 80, tax: tax.vat(7%))
    #item([Seminar], price: 400, tax: tax.exempt(
      grounds: [Steuerfrei nach § 4 Nr. 21 UStG],
    ))
    #discount([Treuerabatt], amount: 5%)
    #surcharge([Express], amount: 20)
    #prepayment(500, name: [Abschlag])
  ]
] else if case == "incl" [
  #line-items(tax-mode: "inclusive")[
    #item([Beratung], price: 1190, tax: tax.vat(19%))
    #item([Fachbuch], price: 107, tax: tax.vat(7%))
    #item([Seminar], price: 400, tax: tax.exempt(
      grounds: [Steuerfrei nach § 4 Nr. 21 UStG],
    ))
    #discount([Treuerabatt], amount: 5%)
    #prepayment(100)
  ]
] else if case == "keep" [
  #line-items[
    #for i in range(1, 19) {
      item(
        [Leistung #i #metadata(i)<kt-name>],
        price: 100 + i,
        description: [#lorem(28) #metadata(i)<kt-desc>],
      )
    }
  ]
] else [
  #line-items[
    #item([Beratung], price: 1000, description: [Workshop und Konzept])
    #item([Reinzeichnung], price: 650)
    #item([Druck], price: 95, quantity: 4)
  ]
]

#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75 5121 0800 1245 1261 99",
  bic: "SOLADEST600",
  show-reference: case != "noref",
)
#signature()
