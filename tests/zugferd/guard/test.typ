// The XML write guard (src/zugferd/guard/) checks every element the
// serializer writes against the tables of its profile, whatever
// invoice-pro's validator says (defense in depth). Each check is triggered
// with the validator bypassed: the element tree of a valid invoice is
// changed after the validation and serialized directly.

#import "/src/lib.typ": *
#import "/src/zugferd/build.typ": build-tree, build-xml, xml-declaration
#import "/src/zugferd/xml.typ": dict-to-xml
#import "/src/zugferd/guard/write.typ": (
  _raw, malformed-kinds, namespaces, root-tag, valid-date-102,
)
#import "/src/zugferd/guard/report.typ": (
  field-of, guard-diagnostics, merge, report-hint, summary-rule,
)
#import "/tests/zugferd/harness.typ": bank, buyer-de, buyer-fr, model-test

// The tree with `value` at `path`: element names, and the index of an item
// of a repeated element.
#let put(tree, path, value) = {
  if path == () { return value }
  let (step, ..rest) = path
  if type(step) == int {
    tree.at(step) = put(tree.at(step), rest, value)
  } else {
    tree.insert(step, put(tree.at(step, default: (:)), rest, value))
  }
  tree
}

// The element at `path` of the tree.
#let get(tree, path) = {
  for step in path { tree = tree.at(step) }
  tree
}

// The tree without the element at `path`.
#let drop(tree, path) = {
  let (step, ..rest) = path
  if rest == () {
    let _ = tree.remove(step)
    return tree
  }
  tree.at(step) = drop(tree.at(step), rest)
  tree
}

// Paths below the root and below the transaction.
#let doc(..path) = (root-tag,) + path.pos()
#let tx(..path) = doc("rsm:SupplyChainTradeTransaction", ..path)
#let line(n, ..path) = tx("ram:IncludedSupplyChainTradeLineItem", n, ..path)
#let buyer(..path) = tx(
  "ram:ApplicableHeaderTradeAgreement",
  "ram:BuyerTradeParty",
  ..path,
)
#let seller(..path) = tx(
  "ram:ApplicableHeaderTradeAgreement",
  "ram:SellerTradeParty",
  ..path,
)

// What the guard finds in a tree: (kind, rule, path) of each finding. The XML
// is always the one the unchecked writer writes.
#let check(model, tree) = {
  let written = dict-to-xml(tree, model.profile.id)
  let unchecked = ""
  for (tag, body) in tree { unchecked += _raw(tag, body) }
  assert.eq(written.xml, unchecked)
  written.findings.map(f => (f.kind, f.rule, f.path.join("/")))
}
// The path of a finding at a path of the tree: an item of a repeated
// element is named with its number, counted from 1.
#let path(..steps) = {
  let out = ()
  for step in steps.pos() {
    if type(step) == int { out.at(-1) += "[" + str(step + 1) + "]" } else {
      out.push(step)
    }
  }
  out.join("/")
}

#let items = [
  #line-items[
    #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
    #item("Travel & <expenses>", price: 49.99, quantity: 1)
  ]
  #payment-goal(days: 14)
  #bank
]

// Calls `test` with the data model of an invoice of `items`.
#let guard-test(test, ..args) = model-test(test, ..args, items)

// --- 1. Valid invoices of every profile: nothing found, the same XML ---
#let valid(model) = {
  let written = dict-to-xml(build-tree(model), model.profile.id)
  assert.eq(written.findings, ())
  assert.eq(xml-declaration + written.xml, build-xml(model))
  // G4: Typst's XML parser reads it as one CrossIndustryInvoice.
  let roots = xml(bytes(build-xml(model))).filter(n => type(n) == dictionary)
  assert.eq(roots.map(n => n.tag), ("CrossIndustryInvoice",))
}
#model-test(valid, zugferd: "en16931", items)
#model-test(valid, zugferd: "xrechnung", recipient: buyer-de, items)
#model-test(valid, zugferd: "basic", items)
#model-test(valid, zugferd: "basic-wl", items)
#model-test(valid, zugferd: "minimum", items)

// A larger invoice: the lines share their structure check.
#model-test(valid, zugferd: "xrechnung", recipient: buyer-de)[
  #line-items[
    #for i in range(40) {
      item([Position #i], price: 10 + i, quantity: calc.rem(i, 3) + 1)
    }
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 2. G2: every code in the lists of every validator of the profile ---
#guard-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let country = buyer("ram:PostalTradeAddress", "ram:CountryID")
  assert.eq(check(model, put(tree, country, "XX")), (
    ("code", "BR-CL-14", path(..country)),
  ))
  // South Sudan is in the Factur-X code list, not in the one of EN 16931.
  assert.eq(check(model, put(tree, country, "SS")), (
    ("code", "BR-CL-14", path(..country)),
  ))
  // The Netherlands Antilles only in the one of EN 16931: the Factur-X
  // Schematron's rule rejects them.
  assert.eq(check(model, put(tree, country, "AN")), (
    ("code", "FX-SCH-A-000036", path(..country)),
  ))
  let quantity = line(0, "ram:SpecifiedLineTradeDelivery", "ram:BilledQuantity")
  assert.eq(check(model, put(tree, quantity + ("@unitCode",), "HOURS")), (
    ("code", "BR-CL-23", path(..quantity)),
  ))
  // The split payment category of Italy (B) is no category of Factur-X.
  let tax = line(
    0,
    "ram:SpecifiedLineTradeSettlement",
    "ram:ApplicableTradeTax",
  )
  let category = tax + ("ram:CategoryCode",)
  assert.eq(check(model, put(tree, category, "B")), (
    ("code", "FX-SCH-A-000179", path(..category)),
  ))
  // The currency of the invoice; the VAT total is then stated in another
  // currency (Factur-X marks it as not used).
  let settlement = tx("ram:ApplicableHeaderTradeSettlement")
  let currency = settlement + ("ram:InvoiceCurrencyCode",)
  assert.eq(check(model, put(tree, currency, "EURO")), (
    ("code", "BR-CL-04", path(..currency)),
    ("xref-other", "IP-GUARD-05", path(..settlement)),
  ))
})

// A code the list of EN 16931 lacks passes where only Factur-X applies, and
// one only Factur-X lacks where it does not apply.
#guard-test(zugferd: "minimum", model => {
  let tree = build-tree(model)
  let country = seller("ram:PostalTradeAddress", "ram:CountryID")
  assert.eq(check(model, put(tree, country, "SS")), ())
})
#guard-test(zugferd: "xrechnung", recipient: buyer-de, model => {
  let tree = build-tree(model)
  let country = buyer("ram:PostalTradeAddress", "ram:CountryID")
  assert.eq(check(model, put(tree, country, "AN")), ())
  let category = line(
    0,
    "ram:SpecifiedLineTradeSettlement",
    "ram:ApplicableTradeTax",
    "ram:CategoryCode",
  )
  assert.eq(check(model, put(tree, category, "B")), ())
})

// --- 2b. G2: the rules of the VAT categories on their tax elements ---
// The rate of a line, allowance or charge, and the VAT amount and exemption
// reason of a VAT breakdown, as the category they state requires.
#guard-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let tax = line(
    0,
    "ram:SpecifiedLineTradeSettlement",
    "ram:ApplicableTradeTax",
  )
  let category = tax + ("ram:CategoryCode",)
  let rate = tax + ("ram:RateApplicablePercent",)
  // IPSI (M) needs a rate above 0: `ram:RateApplicablePercent > 0` in the
  // Schematrons of Factur-X (FX-SCH-A-000246) and EN 16931 (BR-AG-05) that
  // the guard is compiled from, although the text of the rule reads "0
  // (zero) or greater than zero".
  let ipsi = put(put(tree, category, "M"), rate, "0.00")
  assert.eq(check(model, ipsi), (("category", "BR-AG-05", path(..rate)),))
  assert.eq(check(model, put(tree, category, "M")), ())
  // Standard rated at 0 % or without a rate, zero rated at 19 %, and a line
  // not subject to VAT with a rate.
  assert.eq(check(model, put(tree, rate, "0")), (
    ("category", "BR-S-05", path(..rate)),
  ))
  assert.eq(check(model, drop(tree, rate)), (
    ("category", "BR-S-05", path(..rate)),
  ))
  assert.eq(check(model, put(tree, category, "Z")), (
    ("category", "BR-Z-05", path(..rate)),
  ))
  assert.eq(check(model, put(tree, category, "O")), (
    ("category", "BR-O-05", path(..rate)),
  ))
  assert.eq(check(model, drop(put(tree, category, "O"), rate)), ())

  // The VAT breakdown: exempt (E) has no VAT and needs an exemption reason;
  // standard rated (S) has none.
  let breakdown = tx(
    "ram:ApplicableHeaderTradeSettlement",
    "ram:ApplicableTradeTax",
    0,
  )
  let exempt = put(tree, breakdown + ("ram:CategoryCode",), "E")
  assert.eq(check(model, exempt), (
    ("category", "BR-E-09", path(..breakdown, "ram:CalculatedAmount")),
    ("category", "BR-E-10", path(..breakdown, "ram:ExemptionReason")),
  ))
  let reasoned = (:)
  for (key, value) in get(tree, breakdown) {
    reasoned.insert(key, value)
    if key == "ram:TypeCode" {
      reasoned.insert("ram:ExemptionReason", "Exempt")
    }
  }
  assert.eq(check(model, put(tree, breakdown, reasoned)), (
    ("category", "BR-S-10", path(..breakdown, "ram:ExemptionReason")),
  ))
  let exempt = put(
    put(put(tree, breakdown, reasoned), breakdown + ("ram:CategoryCode",), "E"),
    breakdown + ("ram:CalculatedAmount",),
    "0.00",
  )
  assert.eq(check(model, exempt), ())
})

// Document level allowances and charges state the rate of their category.
#model-test(
  model => {
    let tree = build-tree(model)
    let entries = tx(
      "ram:ApplicableHeaderTradeSettlement",
      "ram:SpecifiedTradeAllowanceCharge",
    )
    assert.eq(check(model, tree), ())
    let rate(n) = (
      entries + (n, "ram:CategoryTradeTax", "ram:RateApplicablePercent")
    )
    assert.eq(check(model, put(tree, rate(0), "0.00")), (
      ("category", "BR-S-06", path(..rate(0))),
    ))
    assert.eq(check(model, put(tree, rate(1), "0.00")), (
      ("category", "BR-S-07", path(..rate(1))),
    ))
  },
  zugferd: "en16931",
)[
  #line-items[
    #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
    #discount([Discount], amount: 10%)
    #surcharge([Travel], amount: 30)
  ]
  #payment-goal(days: 14)
  #bank
]

// BASIC WL without lines: its VAT breakdown is missing (BR-CO-18). The
// builder writes none when there are no items.
#model-test(
  model => {
    let tree = build-tree(model)
    let breakdown = tx(
      "ram:ApplicableHeaderTradeSettlement",
      "ram:ApplicableTradeTax",
    )
    assert.eq(check(model, tree), (("min", "BR-CO-18", path(..breakdown)),))
  },
  zugferd: "basic-wl",
)[
  #line-items[]
  #payment-goal(days: 14)
  #bank
]

// --- 3. G2: lexical forms, decimals and dates ---
#guard-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let total = line(
    0,
    "ram:SpecifiedLineTradeSettlement",
    "ram:SpecifiedTradeSettlementLineMonetarySummation",
    "ram:LineTotalAmount",
  )
  assert.eq(check(model, put(tree, total, "12,34")), (
    ("lexical", none, path(..total)),
  ))
  assert.eq(check(model, put(tree, total, "12.345")), (
    ("fraction", "BR-DEC-23", path(..total)),
  ))
  // Decimals beyond the second that are zeros count, as written.
  assert.eq(check(model, put(tree, total, "12.340")), (
    ("fraction", "BR-DEC-23", path(..total)),
  ))
  let date = doc(
    "rsm:ExchangedDocument",
    "ram:IssueDateTime",
    "udt:DateTimeString",
  )
  // Eight digits that name no day: the guard's own rule.
  assert.eq(check(model, put(tree, date + ("",), "20260230")), (
    ("date", "IP-GUARD-08", path(..date)),
  ))
  assert.eq(check(model, put(tree, date + ("",), "2026-01-01")), (
    ("date", "CII-DT-097", path(..date)),
  ))
  assert.eq(check(model, put(tree, date + ("@format",), "610")), (
    ("code", "BR-03", path(..date)),
  ))
  // An allowance whose indicator is neither true nor false is no allowance
  // or charge of the profile (and, added last, out of order).
  let charge = tx(
    "ram:ApplicableHeaderTradeSettlement",
    "ram:SpecifiedTradeAllowanceCharge",
  )
  let allowance = (
    "ram:ChargeIndicator": ("udt:Indicator": "yes"),
    "ram:ActualAmount": "1.00",
    "ram:Reason": "Discount",
  )
  assert.eq(check(model, put(tree, charge, allowance)), (
    ("not-used", "IP-GUARD-05", path(..charge)),
    ("order", none, path(..charge)),
  ))
})

#{
  assert(valid-date-102("20240229"))
  assert(not valid-date-102("20230229"))
  assert(not valid-date-102("21000229"))
  assert(valid-date-102("20000229"))
  assert(not valid-date-102("20261301"))
  assert(not valid-date-102("2026010"))
  assert(not valid-date-102("+2026010"))
  assert(not valid-date-102(20260101))
}

// --- 4. G1: structure ---
#guard-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let agreement = tx("ram:ApplicableHeaderTradeAgreement")
  // An element the schema does not know there.
  assert.eq(check(model, put(tree, agreement + ("ram:Foo",), "bar")), (
    ("unknown", none, path(..agreement, "ram:Foo")),
  ))
  // Out of the order of the schema (the seller after the buyer).
  let moved = drop(tree, seller())
  moved = put(
    moved,
    seller(),
    tree
      .at(root-tag)
      .at(
        "rsm:SupplyChainTradeTransaction",
      )
      .at("ram:ApplicableHeaderTradeAgreement")
      .at("ram:SellerTradeParty"),
  )
  assert.eq(check(model, moved), (
    ("order", none, path(..agreement, "ram:SellerTradeParty")),
  ))
  // Required, and at most once.
  let number = doc("rsm:ExchangedDocument", "ram:ID")
  assert.eq(check(model, drop(tree, number)), (
    ("min", "BR-02", path(..number)),
  ))
  assert.eq(check(model, put(tree, number, ("1", "2"))), (
    ("max", none, path(..number)),
  ))
  // Attributes the schema does not allow, and a required one.
  let quantity = line(0, "ram:SpecifiedLineTradeDelivery", "ram:BilledQuantity")
  assert.eq(check(model, put(tree, quantity + ("@foo",), "1")), (
    ("attribute", none, path(..quantity)),
  ))
  assert.eq(check(model, drop(tree, quantity + ("@unitCode",))), (
    ("attribute-missing", "BR-23", path(..quantity)),
  ))
  // Text where the schema expects elements.
  assert.eq(
    check(model, put(tree, seller("ram:PostalTradeAddress"), "Street 1")),
    (
      ("text", none, path(..seller("ram:PostalTradeAddress"))),
    ),
  )
  // An element without text: EN 16931 allows an empty text, but not an
  // empty decimal or code.
  let name = seller("ram:Name")
  assert.eq(check(model, put(tree, name, (:))), ())
  let total = line(
    0,
    "ram:SpecifiedLineTradeSettlement",
    "ram:SpecifiedTradeSettlementLineMonetarySummation",
    "ram:LineTotalAmount",
  )
  assert.eq(check(model, put(tree, total, (:))), (
    ("lexical", none, path(..total)),
  ))
  let country = buyer("ram:PostalTradeAddress", "ram:CountryID")
  assert.eq(check(model, put(tree, country, (:))), (
    ("code", "BR-CL-14", path(..country)),
  ))
})

// XRechnung forbids empty elements.
#guard-test(zugferd: "xrechnung", recipient: buyer-de, model => {
  let tree = build-tree(model)
  let name = seller("ram:Name")
  assert.eq(check(model, put(tree, name, (:))), (
    ("empty", "PEPPOL-EN16931-R008", path(..name)),
  ))
})

// Elements a profile does not use (the subject of the note of a line, which
// the Factur-X Schematron of BASIC marks as not used).
#guard-test(zugferd: "basic", model => {
  let tree = build-tree(model)
  let note = line(0, "ram:AssociatedDocumentLineDocument", "ram:IncludedNote")
  let found = check(
    model,
    put(tree, note, ("ram:Content": "Note", "ram:SubjectCode": "AAI")),
  )
  assert.eq(found, (
    ("not-used", "IP-GUARD-05", path(..note, "ram:SubjectCode")),
  ))
})

// BASIC WL has no lines: the guard rejects one.
#guard-test(zugferd: "basic-wl", model => {
  let tree = build-tree(model)
  let lines = tx("ram:IncludedSupplyChainTradeLineItem")
  assert.eq(
    lines.at(-1) in tree.at(root-tag).at("rsm:SupplyChainTradeTransaction"),
    false,
  )
  let found = check(model, put(tree, lines, (
    "ram:AssociatedDocumentLineDocument": ("ram:LineID": "1"),
  )))
  assert.eq(found, (("unknown", none, path(..lines)),))
})

// --- 5. Names, namespaces and the root: the document stays well-formed ---
#guard-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let agreement = tx("ram:ApplicableHeaderTradeAgreement")
  let kinds(found) = found.map(f => f.at(0))
  // An invalid element name, and an attribute name with an undeclared
  // prefix: written as given, reported as malformed.
  let found = check(model, put(tree, agreement + ("ram:Foo Bar",), "x"))
  assert.eq(kinds(found), ("unknown", "name"))
  let found = check(model, put(tree, agreement + ("ram:Foo", "@x:y"), "1"))
  assert("name" in kinds(found))
  // A missing namespace declaration.
  let found = check(model, drop(tree, doc("@xmlns:ram")))
  assert.eq(found, (("namespace", none, root-tag),))
  // A second root, and none.
  let found = check(model, tree + ("rsm:Other": "x"))
  assert.eq(found, (("root", none, "rsm:Other"),))
  assert.eq(check(model, (:)), (("root", none, root-tag),))
  // Not even a tree: its text, and no root element (the guard never
  // panics on what it is given).
  let written = dict-to-xml("a < b", "en16931")
  assert.eq(written.xml, "a &lt; b")
  assert.eq(written.findings.map(f => (f.kind, f.path)), (
    ("root", (root-tag,)),
  ))
  assert(("name", "namespace", "root").all(k => k in malformed-kinds))
})

// Text is escaped as before: markup characters, and characters XML does not
// allow, which are left out.
#guard-test(zugferd: "en16931", model => {
  let tree = build-tree(model)
  let name = seller("ram:Name")
  let written = dict-to-xml(
    put(tree, name, "A & B <c> \"d\" 'e'\u{0}"),
    "en16931",
  )
  assert.eq(written.findings, ())
  assert(
    written.xml.contains(
      "<ram:Name>A &amp; B &lt;c&gt; &quot;d&quot; &apos;e&apos;</ram:Name>",
    ),
  )
})

// --- 6. The diagnostics of the findings, and the merge with the validator ---
#let found = (
  (
    kind: "code",
    rule: "BR-CL-14",
    path: buyer("ram:PostalTradeAddress", "ram:CountryID"),
    value: "XX",
    list: "country",
  ),
  (
    kind: "unknown",
    rule: none,
    path: tx("ram:IncludedSupplyChainTradeLineItem[2]", "ram:Foo"),
  ),
)
#let lines = ((id: "1", name: "Consulting"), (id: "2", name: "Travel"))

#{
  // The input fields the paths are written from.
  assert.eq(
    field-of(buyer("ram:PostalTradeAddress", "ram:CountryID"), lines),
    "recipient.country",
  )
  assert.eq(field-of(seller("ram:Name"), lines), "sender.name")
  assert.eq(
    field-of(seller("ram:SpecifiedTaxRegistration[2]", "ram:ID"), lines),
    "sender.vat-id",
  )
  assert.eq(
    field-of(doc("rsm:ExchangedDocument", "ram:IssueDateTime"), lines),
    "date",
  )
  assert.eq(
    field-of(
      tx(
        "ram:IncludedSupplyChainTradeLineItem[2]",
        "ram:SpecifiedTradeProduct",
      ),
      lines,
    ),
    "item 2 (Travel)",
  )
  // A path no input is written to is named as it is.
  assert.eq(
    field-of(doc("rsm:ExchangedDocumentContext"), lines),
    "/" + root-tag + "/rsm:ExchangedDocumentContext",
  )

  let diagnostics = guard-diagnostics(found, lines, "EN 16931 (COMFORT)")
  assert.eq(diagnostics.map(d => d.rule), ("BR-CL-14", "IP-GUARD-01"))
  assert.eq(diagnostics.map(d => d.level), ("error", "error"))
  assert.eq(diagnostics.map(d => d.source), ("guard", "guard"))
  assert.eq(diagnostics.map(d => d.field), (
    "recipient.country",
    "item 2 (Travel)",
  ))
  assert.eq(diagnostics.map(d => d.hint), (report-hint, report-hint))
  assert(diagnostics.first().message.contains("\"XX\""))

  // Without errors of the validator, each finding is a diagnostic.
  let warning = (
    level: "warning",
    rule: "BR-DE-27",
    field: "sender.contact.phone",
  )
  assert.eq(merge((warning,), diagnostics), (warning,) + diagnostics)
  // A finding the validator reports (same rule or field) is left out.
  let error = (level: "error", rule: "BR-CL-14", field: "recipient.country")
  assert.eq(merge((error,), diagnostics.slice(0, 1)), (error,))
  let other = (level: "error", rule: "BR-XX", field: "recipient.country")
  assert.eq(merge((other,), diagnostics.slice(0, 1)), (other,))
  // With errors of the validator, the others are one diagnostic.
  let merged = merge((error,), diagnostics)
  assert.eq(merged.len(), 2)
  assert.eq(merged.last().rule, summary-rule)
  assert.eq(merged.last().field, "item 2 (Travel)")
  assert(merged.last().message.starts-with("1 further problem in the XML"))
  assert.eq(merge((error,), ()), (error,))
}
