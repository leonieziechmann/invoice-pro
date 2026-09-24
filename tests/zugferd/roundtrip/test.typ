// G3, the round trip of the write guard (src/zugferd/guard/roundtrip.typ):
// the XML read back states exactly what the data model states, through the
// binding table of its own (bindings.json). A written invoice passes; an
// element tree changed after the builder, or a model changed after the
// XML was written, gives the findings `differs` (IP-GUARD-10), `dropped`
// (IP-GUARD-11), `extra` (IP-GUARD-12) and `count` (IP-GUARD-13). The strict
// mode compares every line as well and checks the arithmetic of the
// written amounts (guard/strict.typ).

#import "/src/lib.typ": *
#import "/src/zugferd/build.typ": build-tree, xml-declaration
#import "/src/zugferd/xml.typ": dict-to-xml
#import "/src/zugferd/model.typ": profile-terms
#import "/src/zugferd/guard/roundtrip.typ": round-trip
#import "/src/zugferd/guard/strict.typ": strict-findings
#import "/src/zugferd/guard/report.typ": guard-diagnostics
#import "/tests/zugferd/harness.typ": bank, buyer-de, buyer-fr, model-test

// The root element of the XML of an element tree, as Typst's parser reads
// it back.
#let parsed(model, tree) = {
  let written = dict-to-xml(tree, model.profile.id)
  xml(bytes(xml-declaration + written.xml)).find(n => type(n) == dictionary)
}

// The findings of the round trip of a model and its (changed) element tree,
// as (kind, term, path) with the path of local names.
#let trip(model, tree: auto, strict: false) = {
  let tree = if tree == auto { build-tree(model) } else { tree }
  round-trip(
    parsed(model, tree),
    model,
    profile-terms(model.payment, model.profile),
    strict: strict,
  ).map(f => (
    f.kind,
    f.term,
    f
      .path
      .map(step => if type(step) == array {
        step.first() + "[" + str(step.last()) + "]"
      } else { step })
      .join("/"),
  ))
}

// The tree with `value` at `path` (element names, an index of a repeated
// element), or without the element with `value: none`.
#let put(tree, path, value) = {
  let (step, ..rest) = path
  if rest == () {
    if value == none {
      let _ = tree.remove(step)
    } else { tree.insert(step, value) }
    return tree
  }
  if type(step) == int {
    tree.at(step) = put(tree.at(step), rest, value)
  } else { tree.insert(step, put(tree.at(step), rest, value)) }
  tree
}

// The value at `path` of the tree.
#let get(tree, path) = {
  for step in path { tree = tree.at(step) }
  tree
}

// Paths of the tree, and of the findings.
#let doc = "rsm:CrossIndustryInvoice"
#let tx = (doc, "rsm:SupplyChainTradeTransaction")
#let agreement = tx + ("ram:ApplicableHeaderTradeAgreement",)
#let settlement = tx + ("ram:ApplicableHeaderTradeSettlement",)
#let found-tx = "CrossIndustryInvoice/SupplyChainTradeTransaction/"

#let items = [
  #line-items[
    #item(
      [Consulting],
      price: 100,
      quantity: 2,
      unit: unit.hour,
      modifier: discount([Stammkunde], amount: 10%),
    )
    #item([Buch], price: 24.95, quantity: 1, tax: tax.vat(7%))
    #discount([Rabatt], amount: 5%)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 1. The XML of every profile states what the model states ---
#let valid(model) = {
  assert.eq(trip(model), ())
  assert.eq(trip(model, strict: true), ())
  let root = parsed(model, build-tree(model))
  assert.eq(strict-findings(root, model), ())
}
#model-test(valid, zugferd: "en16931", items)
#model-test(valid, zugferd: "xrechnung", recipient: buyer-de, items)
#model-test(valid, zugferd: "basic", items)
#model-test(valid, zugferd: "basic-wl", items)
#model-test(valid, zugferd: "minimum", items)
#model-test(valid, zugferd: "en16931", tax-mode: "inclusive", items)
// Notes, a preceding invoice, a project and a delivery period.
#model-test(
  valid,
  zugferd: "en16931",
  notes: ((text: "Lieferung frei Haus", subject-code: "AAI"), "Danke!"),
  document-type: "corrected",
  preceding-invoice-nr: "2026-00",
  preceding-invoice-date: datetime(year: 2026, month: 8, day: 1),
  project: "Umbau",
  service-period: (
    datetime(year: 2026, month: 8, day: 1),
    datetime(year: 2026, month: 8, day: 31),
  ),
  items,
)

// --- 2. differs (IP-GUARD-10), dropped (IP-GUARD-11), extra (IP-GUARD-12) ---
#model-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  // A text of the tree.
  let number = (doc, "rsm:ExchangedDocument", "ram:ID")
  assert.eq(trip(model, tree: put(tree, number, "2026-02")), (
    ("differs", "BT-1", "CrossIndustryInvoice/ExchangedDocument/ID"),
  ))
  // A model changed after the XML was written.
  let m = model
  m.seller.name = "Andere GmbH"
  assert.eq(trip(m, tree: tree), (
    (
      "differs",
      "BT-27",
      found-tx + "ApplicableHeaderTradeAgreement/SellerTradeParty/Name",
    ),
  ))
  // An amount compares as a decimal: 1.5 is "1.50", but not "1.51".
  let net = (
    settlement
      + (
        "ram:SpecifiedTradeSettlementHeaderMonetarySummation",
        "ram:TaxBasisTotalAmount",
      )
  )
  let value = model.totals.net
  assert.eq(trip(model, tree: put(tree, net, str(value) + "0")), ())
  assert.eq(
    trip(model, tree: put(tree, net, str(value + decimal("0.01")))),
    (
      (
        "differs",
        "BT-109",
        found-tx
          + "ApplicableHeaderTradeSettlement/SpecifiedTradeSettlementHeaderMonetarySummation/TaxBasisTotalAmount",
      ),
    ),
  )
  // A rate is stated in percent.
  let rate = (
    settlement + ("ram:ApplicableTradeTax", 0, "ram:RateApplicablePercent")
  )
  assert.eq(trip(model, tree: put(tree, rate, "19")), ())
  assert.eq(trip(model, tree: put(tree, rate, "0.19")).map(f => f.first()), (
    "differs",
  ))
  // An element left out, and one the model does not have.
  let reference = agreement + ("ram:BuyerReference",)
  let m = model
  m.invoice.buyer-reference = "04011000-12345-34"
  assert.eq(trip(m, tree: tree), (
    (
      "dropped",
      "BT-10",
      found-tx + "ApplicableHeaderTradeAgreement/BuyerReference",
    ),
  ))
  assert.eq(trip(model, tree: put(tree, reference, "04011000-12345-34")), (
    (
      "extra",
      "BT-10",
      found-tx + "ApplicableHeaderTradeAgreement/BuyerReference",
    ),
  ))
  // A date in the format 102.
  let date = (
    doc,
    "rsm:ExchangedDocument",
    "ram:IssueDateTime",
    "udt:DateTimeString",
  )
  assert.eq(
    trip(model, tree: put(tree, date, (
      "@format": "102",
      "": "20260902",
    ))).map(f => f.slice(0, 2)),
    (("differs", "BT-2"),),
  )
  // An attribute: the currency of the VAT total.
  let tax-total = (
    settlement
      + (
        "ram:SpecifiedTradeSettlementHeaderMonetarySummation",
        "ram:TaxTotalAmount",
      )
  )
  assert.eq(
    trip(model, tree: put(tree, tax-total + ("@currencyID",), "USD")),
    (
      (
        "differs",
        "BT-110",
        found-tx
          + "ApplicableHeaderTradeSettlement/SpecifiedTradeSettlementHeaderMonetarySummation/TaxTotalAmount/@currencyID",
      ),
    ),
  )
  // A tax registration of another scheme.
  let m = model
  m.seller.tax-nr = none
  assert.eq(trip(m, tree: tree).map(f => f.slice(0, 2)), (("extra", "BT-32"),))
})[#items]

// A value the profile cannot state is not lost: BASIC WL has no lines, and
// MINIMUM no address of the buyer.
#model-test(zugferd: "minimum", model => {
  assert(model.buyer.address.city != none)
  assert.eq(trip(model), ())
})[#items]

// --- 3. count (IP-GUARD-13): repeated groups and elements ---
#model-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  // A VAT breakdown and a line more in the model than in the XML.
  let m = model
  m.taxes.push(model.taxes.first())
  assert.eq(trip(m, tree: tree), (
    (
      "count",
      "BG-23",
      found-tx + "ApplicableHeaderTradeSettlement/ApplicableTradeTax",
    ),
  ))
  let m = model
  m.lines.push(model.lines.first())
  assert.eq(trip(m, tree: tree), (
    ("count", "BG-25", found-tx + "IncludedSupplyChainTradeLineItem"),
  ))
  // BASIC WL writes no lines.
  let m = model
  m.profile.id = "basic-wl"
  assert.eq(
    trip(m, tree: tree).filter(f => f.at(1) == "BG-25").map(f => f.first()),
    ("count",),
  )
  // An element that occurs twice.
  let name = agreement + ("ram:SellerTradeParty", "ram:Name")
  assert.eq(
    trip(model, tree: put(tree, name, ("Seller GmbH", "Seller GmbH"))),
    (
      (
        "count",
        "BT-27",
        found-tx + "ApplicableHeaderTradeAgreement/SellerTradeParty/Name",
      ),
    ),
  )
  // The element of a wrapper (the date of the invoice in
  // ram:IssueDateTime): twice, and missing next to another element.
  let issued = (doc, "rsm:ExchangedDocument", "ram:IssueDateTime")
  let date = get(tree, issued + ("udt:DateTimeString",))
  assert.eq(
    trip(model, tree: put(tree, issued + ("udt:DateTimeString",), (
      date,
      date,
    ))),
    (
      (
        "count",
        "BT-2",
        "CrossIndustryInvoice/ExchangedDocument/IssueDateTime/DateTimeString",
      ),
    ),
  )
  assert.eq(
    trip(model, tree: put(tree, issued, ("udt:DateTime": "2026-09-01"))),
    (
      (
        "dropped",
        "BT-2",
        "CrossIndustryInvoice/ExchangedDocument/IssueDateTime/DateTimeString",
      ),
    ),
  )
})[#items]

// --- 4. The strict mode: every line ---
#model-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let m = model
  m.lines.at(1).name = "Heft"
  // The standard mode compares the header and the number of lines only.
  assert.eq(trip(m, tree: tree), ())
  assert.eq(trip(m, tree: tree, strict: true), (
    (
      "differs",
      "BT-153",
      found-tx
        + "IncludedSupplyChainTradeLineItem[2]/SpecifiedTradeProduct/Name",
    ),
  ))
  // The allowances and charges of a line, and their number.
  let m = model
  m.lines.at(0).allowances.at(0).amount += decimal("1")
  assert.eq(trip(m, tree: tree, strict: true).map(f => f.slice(0, 2)), (
    ("differs", "BT-136"),
  ))
  let m = model
  m.lines.at(0).allowances = ()
  assert.eq(trip(m, tree: tree, strict: true).map(f => f.slice(0, 2)), (
    ("count", "BG-27"),
  ))
  // The unit of the quantity, an attribute.
  let m = model
  m.lines.at(0).unit-code = "DAY"
  assert.eq(
    trip(m, tree: tree, strict: true).map(f => f.at(2).split("/").last()),
    ("@unitCode",),
  )
})[#items]

// --- 5. The strict mode: the arithmetic of the written amounts ---
#model-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let root(tree) = parsed(model, tree)
  let sums = (
    settlement + ("ram:SpecifiedTradeSettlementHeaderMonetarySummation",)
  )
  let rules(tree) = strict-findings(root(tree), model).map(f => f.rule)
  // A line net amount the sum of the lines (BT-106) and the taxable amount
  // of its VAT category do not add up to.
  let net = (
    tx
      + (
        "ram:IncludedSupplyChainTradeLineItem",
        0,
        "ram:SpecifiedLineTradeSettlement",
        "ram:SpecifiedTradeSettlementLineMonetarySummation",
        "ram:LineTotalAmount",
      )
  )
  assert.eq(rules(put(tree, net, "999.00")), ("BR-CO-10", "BR-S-08"))
  // The totals.
  assert.eq(rules(put(tree, sums + ("ram:AllowanceTotalAmount",), "1.00")), (
    "BR-CO-11",
    "BR-CO-13",
  ))
  assert.eq(
    rules(put(tree, sums + ("ram:TaxTotalAmount",), (
      "@currencyID": "EUR",
      "": "1.00",
    ))),
    ("BR-CO-14", "BR-CO-15"),
  )
  assert.eq(rules(put(tree, sums + ("ram:GrandTotalAmount",), "1.00")), (
    "BR-CO-15",
    "BR-CO-16",
  ))
  assert.eq(rules(put(tree, sums + ("ram:DuePayableAmount",), "1.00")), (
    "BR-CO-16",
  ))
  // A VAT amount that is not the taxable amount times the rate, within 1.
  let amount = (
    settlement + ("ram:ApplicableTradeTax", 0, "ram:CalculatedAmount")
  )
  let stated = decimal(get(tree, amount))
  assert.eq(rules(put(tree, amount, str(stated + decimal("1.01")))), (
    "BR-CO-14",
    "BR-CO-17",
  ))
  // Within 1: only the VAT total (BT-110) no longer adds up.
  assert.eq(rules(put(tree, amount, str(stated + decimal("0.99")))), (
    "BR-CO-14",
  ))
})[#items]

// The tolerance of the exempt categories: within 1, not exactly.
#model-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let basis = settlement + ("ram:ApplicableTradeTax", 0, "ram:BasisAmount")
  let value = decimal(get(tree, basis))
  let rules(tree) = strict-findings(parsed(model, tree), model).map(f => f.rule)
  assert.eq(rules(put(tree, basis, str(value + decimal("0.5")))), ())
  assert.eq(rules(put(tree, basis, str(value + decimal("1.5")))), ("BR-E-08",))
})[
  #line-items[
    #item(
      [Behandlung],
      price: 100,
      quantity: 1,
      tax: tax.exempt(grounds: "Steuerfrei nach § 4 Nr. 14 UStG"),
    )
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 6. The report names the rule, the input and the values ---
#model-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let m = model
  m.invoice.number = "2026-02"
  let found = round-trip(
    parsed(model, tree),
    m,
    profile-terms(m.payment, m.profile),
  )
  let d = guard-diagnostics(found, m.lines, m.profile.name).first()
  assert.eq(d.rule, "IP-GUARD-10")
  assert.eq(d.level, "error")
  assert.eq(d.source, "guard")
  assert.eq(d.field, "invoice-nr")
  assert.eq(d.path, "/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID")
  assert(d.message.contains("\"2026-01\""))
  assert(d.message.contains("\"2026-02\""))
  // A rate as the XML states it, in percent.
  let m = model
  m.taxes.at(0).rate = decimal("0.2")
  let d = guard-diagnostics(
    round-trip(parsed(model, tree), m, profile-terms(m.payment, m.profile)),
    m.lines,
    m.profile.name,
  ).first()
  assert(d.message.contains("\"20.0"))
  let rules = (
    ("dropped", "IP-GUARD-11"),
    ("extra", "IP-GUARD-12"),
    (
      "count",
      "IP-GUARD-13",
    ),
  )
  for (kind, rule) in rules {
    let d = guard-diagnostics(
      (
        (
          kind: kind,
          rule: none,
          path: ("CrossIndustryInvoice",),
          term: "BT-1",
          stated: 2,
          expected: 1,
          k: "t",
        ),
      ),
      m.lines,
      m.profile.name,
    ).first()
    assert.eq(d.rule, rule)
  }
})[#items]
