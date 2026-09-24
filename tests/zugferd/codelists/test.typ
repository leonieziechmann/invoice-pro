// The code lists of the e-invoice validation: the lists of the write guard
// that the rules check codes with (`validator` of src/zugferd/guard/lists.typ).
// tools/zugferd/gen_guard.py intersects them from every official validation
// of a profile: the Factur-X 1.0.07 code lists and the EN 16931 Schematron
// 1.3.12 of Mustang and 1.3.16 of the KoSIT validator. A list is a string of
// codes, each between two spaces.

#import "/src/zugferd/guard/lists.typ": validator as lists
#import "/src/zugferd/rules/engine.typ": in-list
#import "/src/zugferd/codelists.typ"

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
  // ISO 4217: Factur-X, and what EN 16931 keeps of it.
  assert.eq(size(lists.currency.factur-x), 179)
  assert.eq(size(lists.currency.every), 170)
  assert.eq(size(lists.unit.every), 2162)
  assert.eq(size(lists.eas.every), 92)
  assert.eq(size(lists.icd.every), 225)
  assert.eq(size(lists.vat-category.every), 9)
  assert.eq(size(lists.payment-means.every), 84)
  assert.eq(size(lists.vatex.every), 59)
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

// --- 4. The codes of the newest EN 16931 list (1.3.16 of KoSIT) that the
// lists of a profile lack: the validation of the profile rejects them, so
// the rules name them as codes it does not know yet ---
#{
  for (name, entry) in lists {
    if "newer" not in entry { continue }
    for code in codes(entry.newer) {
      assert(not in-list(entry.every, code), message: name + ": " + code)
      assert(
        not in-list(entry.at("xrechnung", default: entry.every), code),
        message: name + ": " + code,
      )
      if "factur-x" in entry {
        assert(not in-list(entry.factur-x, code), message: name + ": " + code)
      }
    }
  }
  // The withdrawn codes: no profile based on EN 16931 accepts them.
  for (name, entry) in lists {
    if "withdrawn" not in entry { continue }
    for code in codes(entry.withdrawn) {
      assert(not in-list(entry.every, code), message: name + ": " + code)
      assert(
        not in-list(entry.at("xrechnung", default: entry.every), code),
        message: name + ": " + code,
      )
    }
  }
  assert.eq(codes(lists.currency.newer), ("CNH", "VED", "XCG", "ZWG"))
  assert(in-list(lists.eas.newer, "0240"))
  assert(in-list(lists.icd.newer, "0240"))
  assert(in-list(lists.vatex.newer, "VATEX-EU-144"))
}

// --- 5. The arrays the data model reads (src/zugferd/codelists.typ) ---
#{
  assert.eq(codelists.countries, codes(lists.country.every))
  assert.eq(codelists.units, codes(lists.unit.every))
  assert("DE" in codelists.countries)
  assert("SS" not in codelists.countries)
  assert("C62" in codelists.units)
  assert("C6" not in codelists.units)
}

// --- 6. A code that the validation of a profile rejects is an error in that
// profile, also when only the newest official validation rejects it: the
// EN 16931 Schematron 1.3.16 of the KoSIT validator, whose lists have
// withdrawn codes that the older lists of Mustang still have. KoSIT does not
// validate BASIC, whose validation accepts them: invoice-pro rejects them
// there all the same, as a receiver that applies the current list does
// (IP-CODE-01). A withdrawn currency is allowed wherever the Factur-X
// validation of the profile accepts it, with a warning where a validator
// with the newest list rejects it (maintainer decision): only XRechnung
// rejects it ---
#import "/src/lib.typ": item, line-items, payment-goal
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/build.typ": build-tree
#import "/src/zugferd/xml.typ": dict-to-xml
#import "/tests/zugferd/harness.typ": (
  bank, diagnostic, model-test, rules, xml-elements,
)

// The rules of the code lists the write guard finds broken in the XML of a
// model.
#let guard-code-rules(model) = {
  let found = ()
  for f in dict-to-xml(build-tree(model), model.profile.id).findings {
    if f.kind == "code" and f.rule not in found { found.push(f.rule) }
  }
  found.sorted()
}

// Currencies the EN 16931 validation has withdrawn: the Netherlands Antillean
// guilder (ANG, the Caribbean guilder XCG since 2025), the Bulgarian lev
// (BGN, the euro since 2026), the Cuban convertible peso (CUC), the Croatian
// kuna (HRK, the euro since 2023) and the Zimbabwe dollar (ZWL, Zimbabwe Gold
// since 2024). The Factur-X list still has them.
#model-test(model => {
  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  for code in ("ANG", "BGN", "CUC", "HRK", "ZWL") {
    assert(in-list(lists.currency.factur-x, code), message: code)
    assert(not in-list(lists.currency.every, code), message: code)
    assert(in-list(lists.currency.withdrawn, code), message: code)
    m.currency = code
    for id in ("basic", "en16931") {
      m.profile = resolve-profile(id, "FR")
      assert.eq(rules(m), (), message: code + " in " + id)
      assert.eq(
        rules(m, level: "warning"),
        ("IP-CODE-01",),
        message: code + " in " + id,
      )
      assert.eq(guard-code-rules(m), (), message: code + " in " + id)
    }
    for id in ("minimum", "basic-wl") {
      m.profile = resolve-profile(id, "FR")
      assert.eq(
        rules(m) + rules(m, level: "warning"),
        (),
        message: code + " in " + id,
      )
      assert.eq(guard-code-rules(m), (), message: code + " in " + id)
    }
    m.profile = resolve-profile("xrechnung", "DE")
    assert("BR-CL-04" in rules(m), message: code + " in xrechnung")
    assert.eq(
      guard-code-rules(m),
      ("BR-CL-03", "BR-CL-04"),
      message: code + " in xrechnung",
    )
  }
  m.currency = "BGN"
  m.profile = resolve-profile("en16931", "FR")
  let d = diagnostic(m, "IP-CODE-01")
  assert.eq(d.level, "warning")
  assert.eq(d.field, "locale")
  assert.eq(
    d.message,
    "The invoice currency code (BT-5) \"BGN\" was withdrawn from the newest version of the EN 16931 code list (1.3.16). The Factur-X validation of the EN 16931 (COMFORT) profile still accepts it, but a validator with the current list, such as KoSIT, rejects the e-invoice.",
  )
  assert.eq(
    d.hint,
    "Invoice in the currency that replaced it, e.g. \"EUR\" for \"BGN\" and \"HRK\".",
  )
  m.profile = resolve-profile("xrechnung", "DE")
  assert(
    diagnostic(m, "BR-CL-04").hint.contains("with a warning in \"basic\""),
    message: diagnostic(m, "BR-CL-04").hint,
  )
  // The withdrawn Mauritanian ouguiya (MRO) is no code of Factur-X, whose
  // validation rejects it in MINIMUM, BASIC WL and BASIC; KoSIT rejects it
  // in EN 16931.
  m.currency = "MRO"
  for id in ("minimum", "basic-wl", "basic") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), ("FX-SCH-A-000040",), message: id)
  }
  m.profile = resolve-profile("en16931", "FR")
  assert.eq(rules(m), ("BR-CL-04",))
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 7. Electronic address schemes the EAS code list has withdrawn: 9901
// is no longer in the list of the EN 16931 Schematron 1.3.16, which KoSIT
// applies to EN 16931 and XRechnung; in every other profile, invoice-pro
// rejects it as IP-CODE-01 ---
#model-test(model => {
  assert(not in-list(lists.eas.every, "9901"))
  assert(not in-list(lists.eas.xrechnung, "9901"))
  let m = model
  m.buyer.electronic-address = (scheme: "9901", id: "12345678")
  assert.eq(rules(m), ("BR-CL-25",))
  for id in ("basic-wl", "basic") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), ("IP-CODE-01",), message: id)
  }
  let d = diagnostic(m, "IP-CODE-01")
  assert.eq(d.field, "recipient.electronic-address")
  assert(
    d.message.starts-with(
      "The scheme \"9901\" of the buyer electronic address (BT-49) was withdrawn",
    ),
    message: d.message,
  )
  assert.eq(d.hint, "Use a current scheme, e.g. \"EM\" for an email address.")
  m.buyer.electronic-address = (scheme: "0088", id: "4000001123452")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 8. A code only the newest EN 16931 list has is named as such: the
// validation of the profile does not know it yet, in every profile ---
#let not-yet(subject) = (
  subject
    + " is not in the code list of the Factur-X validation yet: only the newest version of the EN 16931 code list has it."
)
#let not-yet-hint = "Use another code while the validators of the Factur-X profiles do not know it yet."

#model-test(model => {
  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  // The Caribbean guilder (XCG), which replaced ANG in 2025: the rule of the
  // Factur-X Schematron in MINIMUM and BASIC WL, which apply it alone.
  m.currency = "XCG"
  for (id, rule) in (
    ("minimum", "FX-SCH-A-000040"),
    ("basic-wl", "FX-SCH-A-000040"),
    ("en16931", "BR-CL-04"),
  ) {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), (rule,), message: id)
    let d = diagnostic(m, rule)
    assert.eq(d.message, not-yet("The invoice currency code (BT-5) \"XCG\""))
    assert.eq(d.hint, not-yet-hint)
  }
  // A code of no list at all is not.
  m.currency = "XYZ"
  assert(
    diagnostic(m, "BR-CL-04").message.ends-with("is not an ISO 4217 code."),
  )
  // XRechnung is validated with the lists of EN 16931 alone, whose older
  // version lacks the code.
  m.currency = "XCG"
  m.profile = resolve-profile("xrechnung", "DE")
  let d = diagnostic(m, "BR-CL-04")
  assert.eq(
    d.message,
    "The invoice currency code (BT-5) \"XCG\" is not in the code list of every validator of XRechnung yet: only the newest version of the EN 16931 code list has it.",
  )
  assert.eq(
    d.hint,
    "Use another code while the validators of XRechnung do not know it yet.",
  )
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

#model-test(model => {
  // An electronic address scheme of 2025 (EAS 0240).
  let m = model
  m.buyer.electronic-address = (scheme: "0240", id: "12345678")
  assert.eq(rules(m), ("BR-CL-25",))
  let d = diagnostic(m, "BR-CL-25")
  assert.eq(d.field, "recipient.electronic-address")
  assert.eq(
    d.message,
    not-yet("The scheme \"0240\" of the buyer electronic address (BT-49)"),
  )
  assert.eq(d.hint, not-yet-hint)

  // An ISO/IEC 6523 scheme of 2025 (ICD 0240) as the scheme of the global
  // identifier and of the legal registration identifier.
  let m = model
  m.seller.global-id = (scheme: "0240", id: "12345678")
  assert.eq(rules(m), ("BR-CL-10",))
  let d = diagnostic(m, "BR-CL-10")
  assert.eq(d.message, not-yet("The scheme \"0240\" of the global identifier"))
  assert.eq(d.hint, not-yet-hint)
  let m = model
  m.buyer.legal-id = (scheme: "0240", id: "12345678")
  assert.eq(rules(m), ("BR-CL-11",))
  let d = diagnostic(m, "BR-CL-11")
  assert.eq(d.field, "recipient.legal-id")
  assert.eq(
    d.message,
    not-yet(
      "The scheme \"0240\" of the buyer legal registration identifier (BT-47)",
    ),
  )
  assert.eq(d.hint, not-yet-hint)
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 9. XRechnung applies the code lists of EN 16931 alone, which have codes
// the Factur-X lists lack: the electronic address schemes 0219 and 0220, the
// Netherlands Antilles (AN) and the São Tomé dobra (STD). The Factur-X
// profiles reject them with the rule of the Factur-X Schematron ---
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
  assert.eq(rules(m), ("FX-SCH-A-000031",))
  let d = diagnostic(m, "FX-SCH-A-000031")
  assert.eq(
    d.message,
    factur-x-only(
      "The scheme \"0219\" of the buyer electronic address (BT-49)",
    ),
  )
  assert(d.hint.ends-with("accepts it."), message: d.hint)
  for id in ("basic-wl", "basic") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), ("FX-SCH-A-000031",), message: id)
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
  assert.eq(rules(m), ("FX-SCH-A-000036",))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000036").message,
    factur-x-only("The buyer country code (BT-55) \"AN\""),
  )
  m.profile = resolve-profile("xrechnung", "DE")
  assert.eq(code-rules(m), ())

  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  m.currency = "STD"
  assert.eq(rules(m), ("FX-SCH-A-000040",))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000040").message,
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
  assert.eq(rules(m), ("BR-B-01", "FX-SCH-A-000179"))
  assert.eq(
    diagnostic(m, "FX-SCH-A-000179").message,
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

// --- 10. MINIMUM and BASIC WL apply the code lists of the Factur-X
// Schematron alone: its rules name a code none of its lists has ---
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
  assert.eq(rules(m), ("BR-CL-14",))

  let m = model
  m.seller.legal-id = (scheme: "9999", id: "12345678")
  for id in ("minimum", "basic-wl") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), ("FX-SCH-A-000031",), message: id)
  }
  let m = model
  m.profile = resolve-profile("basic-wl", "FR")
  m.buyer.global-id = (scheme: "9999", id: "12345678")
  assert.eq(rules(m), ("FX-SCH-A-000031",))
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
