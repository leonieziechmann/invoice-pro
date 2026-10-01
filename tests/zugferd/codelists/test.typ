// The code lists of the e-invoice validation (src/zugferd/code-lists.typ).
// tools/zugferd/gen_guard.py intersects them from every official validation
// of a profile: the Factur-X 1.09.2 code lists and the EN 16931 Schematron
// 1.3.16 of Mustang and of the KoSIT validator. A list is a string of codes,
// each between two spaces.

#import "/src/zugferd/code-lists.typ": lists
#import "/src/zugferd/rules/engine.typ": in-list

#let codes(list) = list.trim().split(" ")

// --- 1. The lists contain codes only: no empty code, no code twice ---
#for (name, entry) in lists {
  for (kind, list) in entry {
    let label = name + "." + kind
    assert(list.starts-with(" ") and list.ends-with(" "), message: label)
    assert(not list.contains("  "), message: label + " has an empty code")
    let all = codes(list)
    assert(all.len() > 0, message: label + " is empty")
    assert.eq(all.dedup().len(), all.len(), message: label + " has duplicates")
  }
}

// --- 2. The sizes of the lists: those of the validator before the lists of
// the write guard replaced its own (the EN 16931 lists are the intersection
// of both versions) ---
#{
  let size(list) = codes(list).len()
  // ISO 3166-1 of EN 16931, without the withdrawn "AN"; Factur-X also has
  // South Sudan ("SS"), which MINIMUM and BASIC WL can state.
  assert.eq(size(lists.country.every), 250)
  assert.eq(size(lists.country.factur-x), 251)
  // ISO 4217: what EN 16931 and Factur-X share, and the São Tomé dobra
  // (STN), which only Factur-X has.
  assert.eq(size(lists.currency.every), 177)
  assert.eq(size(lists.currency.factur-x), 178)
  assert.eq(size(lists.unit.every), 2162)
  assert.eq(size(lists.eas.every), 102)
  assert.eq(size(lists.icd.every), 235)
  assert.eq(size(lists.vat-category.every), 9)
  assert.eq(size(lists.payment-means.every), 84)
  assert.eq(size(lists.vatex.every), 88)
}

// --- 3. Lookups: a code is in a list as a whole ---
#{
  assert(in-list(lists.country.every, "DE"))
  assert(in-list(lists.unit.every, "C62"))
  assert(in-list(lists.unit.every, "HUR"))
  assert(in-list(lists.eas.every, "0088"))
  assert(in-list(lists.eas.every, "EM"))
  assert(in-list(lists.icd.every, "0088"))
  assert(in-list(lists.vat-category.every, "S"))
  // Not a part of a code, of two codes, another case or no code at all.
  for code in ("de", "D", "C6", "DE ", " DE", "DE FR", "", none, 49) {
    assert(not in-list(lists.country.every, code), message: repr(code))
    assert(not in-list(lists.unit.every, code), message: repr(code))
  }
  assert(not in-list(lists.eas.every, "0088 0096"))
  // South Sudan: in the Factur-X list only; "EL" is only the prefix of
  // Greek VAT identifiers.
  assert(in-list(lists.country.factur-x, "SS"))
  assert(not in-list(lists.country.every, "SS"))
  assert(not in-list(lists.country.factur-x, "EL"))
  // UNTDID 4461 as EN 16931 accepts it (BR-CL-16): 71 to 73 and 79 to 90
  // are not among its codes.
  for code in ("1", "10", "30", "48", "49", "54", "55", "58", "59", "ZZZ") {
    assert(in-list(lists.payment-means.every, code), message: code)
  }
  for code in ("0", "058", "71", "79", "90", "99", "zzz") {
    assert(not in-list(lists.payment-means.every, code), message: code)
  }
}

// --- 4. Mustang 2.26.0 and KoSIT apply the same EN 16931 Schematron
// (1.3.16): no code is only in the newest list (`newer`) or withdrawn from it
// (`withdrawn`), which the lists would name if the versions differed again.
// The codes of 2024 and 2025 are in every list ---
#{
  for (name, entry) in lists {
    assert("newer" not in entry, message: name)
    assert("withdrawn" not in entry, message: name)
  }
  for code in ("CNH", "VED", "XCG", "ZWG") {
    assert(in-list(lists.currency.every, code), message: code)
  }
  assert(in-list(lists.eas.every, "0240"))
  assert(in-list(lists.icd.every, "0240"))
  assert(in-list(lists.vatex.every, "VATEX-EU-144"))
}

// --- 5. A withdrawn code is an error in every profile: the Bulgarian lev
// (BGN, the euro since 2026), the Croatian kuna (HRK), the Netherlands
// Antillean guilder (ANG), the Cuban convertible peso (CUC), the Zimbabwe
// dollar (ZWL) and the Mauritanian ouguiya of before 2018 (MRO) are in no
// list of the validators any more, neither of EN 16931 nor of Factur-X ---
#import "/src/lib.typ": item, line-items, payment-goal
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/build.typ": build-tree
#import "/tools/zugferd/guard/write.typ": write
#import "/tests/zugferd/harness.typ": (
  bank, diagnostic, model-test, rules, xml-elements,
)

// The rules of the code lists the write guard of the test oracle finds
// broken in the XML of a model.
#let guard-code-rules(model) = {
  let found = ()
  for f in write(build-tree(model), model.profile.id).findings {
    if f.kind == "code" and f.rule not in found { found.push(f.rule) }
  }
  found.sorted()
}

#model-test(model => {
  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  for code in ("ANG", "BGN", "CUC", "HRK", "MRO", "ZWL") {
    assert(not in-list(lists.currency.factur-x, code), message: code)
    m.currency = code
    for (id, rule) in (
      ("minimum", "FX-SCH-A-000040"),
      ("basic-wl", "FX-SCH-A-000464"),
      ("basic", "FX-SCH-A-000514"),
      ("en16931", "BR-CL-04"),
    ) {
      m.profile = resolve-profile(id, "FR")
      assert.eq(rules(m), (rule,), message: code + " in " + id)
      assert.eq(rules(m, level: "warning"), (), message: code + " in " + id)
      assert(guard-code-rules(m) != (), message: code + " in " + id)
    }
    m.profile = resolve-profile("xrechnung", "DE")
    assert("BR-CL-04" in rules(m), message: code + " in xrechnung")
    assert.eq(
      guard-code-rules(m),
      ("BR-CL-03", "BR-CL-04"),
      message: code + " in xrechnung",
    )
  }
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 6. The electronic address scheme 9901, which the EAS code lists have
// withdrawn: the rule of the CEN Schematron in EN 16931, the one of the
// Factur-X Schematron of the position in BASIC WL and BASIC, whose
// validation applies the Factur-X list alone ---
#model-test(model => {
  assert(not in-list(lists.eas.every, "9901"))
  assert(not in-list(lists.eas.xrechnung, "9901"))
  let m = model
  m.buyer.electronic-address = (scheme: "9901", id: "12345678")
  assert.eq(rules(m), ("BR-CL-25",))
  m.profile = resolve-profile("basic", "FR")
  assert.eq(rules(m), ("FX-SCH-A-000498",))
  m.profile = resolve-profile("basic-wl", "FR")
  assert.eq(rules(m), ("FX-SCH-A-000429",))
  m.buyer.electronic-address = (scheme: "0088", id: "4000001123452")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 7. The codes of 2024 and 2025 are accepted in every profile ---
#model-test(model => {
  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  // The Caribbean guilder (XCG), which replaced ANG in 2025.
  m.currency = "XCG"
  for id in ("minimum", "basic-wl", "basic", "en16931") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), (), message: id)
  }
  // A code of no list at all is not.
  m.currency = "XYZ"
  assert(
    diagnostic(m, "BR-CL-04").message.ends-with("is not an ISO 4217 code."),
  )
  // An electronic address scheme (EAS 0240) and an ISO/IEC 6523 scheme (ICD
  // 0240) of 2025.
  let m = model
  m.buyer.electronic-address = (scheme: "0240", id: "12345678")
  assert.eq(rules(m), ())
  let m = model
  m.seller.global-id = (scheme: "0240", id: "12345678")
  assert.eq(rules(m), ())
  let m = model
  m.buyer.legal-id = (scheme: "0240", id: "12345678")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 8. XRechnung applies the code lists of EN 16931 alone, which have codes
// the Factur-X lists lack: the electronic address schemes 0219 and 0220, the
// Netherlands Antilles (AN) and the São Tomé dobra of before 2018 (STD). The
// Factur-X profiles reject them with the rule of the Factur-X Schematron of
// the position, whose id differs from profile to profile ---
#let factur-x-only(subject) = (
  subject
    + " is not in the code list of the Factur-X validation, although the code list of EN 16931 has it."
)
#let code-rules(model) = rules(model).filter(rule => (
  rule.starts-with("BR-CL-") or rule.starts-with("FX-")
))

#model-test(model => {
  for code in ("0219", "0220") {
    assert(in-list(lists.eas.xrechnung, code), message: code)
    assert(not in-list(lists.eas.every, code), message: code)
  }
  let m = model
  m.buyer.electronic-address = (scheme: "0219", id: "12345678")
  assert.eq(rules(m), ("FX-SCH-A-000571",))
  let d = diagnostic(m, "FX-SCH-A-000571")
  assert.eq(
    d.message,
    factur-x-only(
      "The scheme \"0219\" of the buyer electronic address (BT-49)",
    ),
  )
  assert(d.hint.ends-with("accepts it."), message: d.hint)
  for (id, rule) in (
    ("basic-wl", "FX-SCH-A-000429"),
    ("basic", "FX-SCH-A-000498"),
  ) {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), (rule,), message: id)
  }
  // ... which XRechnung states
  m.profile = resolve-profile("xrechnung", "DE")
  assert.eq(code-rules(m), ())
  assert(
    xml-elements(m, "ram:URIID").contains(
      "<ram:URIID schemeID=\"0219\">12345678</ram:URIID>",
    ),
    message: repr(xml-elements(m, "ram:URIID")),
  )

  let m = model
  m.buyer.address.country = "AN"
  assert.eq(rules(m), ("FX-SCH-A-000568",))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000568").message,
    factur-x-only("The buyer country code (BT-55) \"AN\""),
  )
  m.profile = resolve-profile("xrechnung", "DE")
  assert.eq(code-rules(m), ())

  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  m.currency = "STD"
  assert.eq(rules(m), ("FX-SCH-A-000595",))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000595").message,
    factur-x-only("The invoice currency code (BT-5) \"STD\""),
  )
  m.profile = resolve-profile("xrechnung", "DE")
  assert.eq(code-rules(m), ())

  // The split payment of Italy (B) is no category of Factur-X; XRechnung
  // accepts the code. Its rules apply in every profile based on EN 16931
  // (BR-B-01: a German seller).
  let m = model
  m.taxes.at(0).category = "B"
  m.lines.at(0).category = "B"
  assert.eq(rules(m), ("BR-B-01", "FX-SCH-A-000587"))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000587").message,
    "The VAT category \"B\" is not in the code list of the Factur-X validation, although the code list of EN 16931 has it.",
  )
  m.profile = resolve-profile("xrechnung", "DE")
  assert.eq(code-rules(m), ())
  assert("BR-B-01" in rules(m), message: repr(rules(m)))
  // ... so B is one of the categories it allows
  m.taxes.at(0).category = "AA"
  m.lines.at(0).category = "AA"
  assert(
    diagnostic(m, "BR-CL-18")
      .message
      .ends-with(
        "is not allowed in EN 16931 (allowed: S, Z, E, AE, K, G, O, L, M, B).",
      ),
  )
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 9. MINIMUM, BASIC WL and BASIC apply the code lists of the Factur-X
// Schematron alone: its rules name a code none of its lists has, and
// EN 16931 the ones of the CEN Schematron ---
#model-test(model => {
  let m = model
  m.profile = resolve-profile("minimum", "FR")
  m.seller.address.country = "XX"
  assert.eq(rules(m), ("FX-SCH-A-000036",))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000036").message,
    "The seller country code (BT-40) \"XX\" is not in the ISO 3166-1 code list of Factur-X.",
  )
  m.profile = resolve-profile("basic", "FR")
  assert.eq(rules(m), ("FX-SCH-A-000502",))
  m.profile = resolve-profile("en16931", "FR")
  assert.eq(rules(m), ("BR-CL-14",))

  let m = model
  m.seller.legal-id = (scheme: "9999", id: "12345678")
  for (id, rule) in (
    ("minimum", "FX-SCH-A-000410"),
    ("basic-wl", "FX-SCH-A-000444"),
  ) {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), (rule,), message: id)
  }
  let m = model
  m.profile = resolve-profile("basic-wl", "FR")
  m.buyer.global-id = (scheme: "9999", id: "12345678")
  assert.eq(rules(m), ("FX-SCH-A-000421",))
  let m = model
  m.profile = resolve-profile("basic-wl", "FR")
  m.taxes.at(0).category = "AA"
  assert.eq(rules(m), ("FX-SCH-A-000179",))
  assert(
    diagnostic(m, "FX-SCH-A-000179")
      .message
      .ends-with(
        "is not allowed in Factur-X (allowed: S, Z, E, AE, K, G, O, L, M).",
      ),
  )
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]
