// The code lists of the e-invoice validation: the lists of the write guard
// that the rules check codes with (`validator` of src/zugferd/guard/lists.typ).
// tools/zugferd/gen_guard.py intersects them from every official validation
// of a profile: the Factur-X 1.0.07 code lists and the EN 16931 Schematron
// 1.3.12 of Mustang and 1.3.16 of the KoSIT validator. A list is a string of
// codes, each between two spaces.

#import "/src/zugferd/guard/lists.typ": validator as lists
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
      if "factur-x" in entry {
        assert(not in-list(entry.factur-x, code), message: name + ": " + code)
      }
    }
  }
  assert.eq(codes(lists.currency.newer), ("CNH", "VED", "XCG", "ZWG"))
  assert(in-list(lists.eas.newer, "0240"))
  assert(in-list(lists.icd.newer, "0240"))
  assert(in-list(lists.vatex.newer, "VATEX-EU-144"))
}

// --- 5. A code that the validation of a profile rejects is an error in that
// profile, also when only the newest official validation rejects it: the
// EN 16931 Schematron 1.3.16 of the KoSIT validator, whose lists have
// withdrawn codes that the older lists of Mustang still have ---
#import "/src/lib.typ": item, line-items, payment-goal
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": bank, diagnostic, model-test, rules

// Currencies the EN 16931 validation has withdrawn: the Netherlands Antillean
// guilder (ANG, the Caribbean guilder XCG since 2025), the Bulgarian lev
// (BGN, the euro since 2026), the Cuban convertible peso (CUC), the Croatian
// kuna (HRK, the euro since 2023) and the Zimbabwe dollar (ZWL, Zimbabwe Gold
// since 2024). The Factur-X list of MINIMUM and BASIC WL still has them.
#model-test(model => {
  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  for code in ("ANG", "BGN", "CUC", "HRK", "ZWL") {
    assert(in-list(lists.currency.factur-x, code), message: code)
    assert(not in-list(lists.currency.every, code), message: code)
    m.currency = code
    for id in ("basic", "en16931") {
      m.profile = resolve-profile(id, "FR")
      assert.eq(rules(m), ("BR-CL-04",), message: code + " in " + id)
    }
    assert(
      diagnostic(m, "BR-CL-04").message.contains("\"" + code + "\""),
      message: code,
    )
    m.profile = resolve-profile("basic-wl", "FR")
    assert.eq(rules(m), (), message: code + " in basic-wl")
  }
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 6. Electronic address schemes the EAS code list has withdrawn: 9901
// is no longer in the list of the EN 16931 Schematron 1.3.16 ---
#model-test(model => {
  assert(not in-list(lists.eas.every, "9901"))
  let m = model
  m.buyer.electronic-address = (scheme: "9901", id: "12345678")
  assert.eq(rules(m), ("BR-CL-25",))
  m.buyer.electronic-address = (scheme: "0088", id: "4000001123452")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 7. A code only the newest EN 16931 list has is named as such: the
// validation of the profile does not know it yet, in every profile ---
#let not-yet(subject) = (
  subject
    + " is not in the code list of the Factur-X validation yet: only the newest version of the EN 16931 code list has it."
)
#let not-yet-hint = "Use another code while the validators of the Factur-X profiles do not know it yet."

#model-test(model => {
  let m = model
  m.printed-currency = (symbol: none, amount: none, price: none)
  // The Caribbean guilder (XCG), which replaced ANG in 2025.
  m.currency = "XCG"
  for id in ("minimum", "basic-wl", "en16931") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), ("BR-CL-04",), message: id)
    let d = diagnostic(m, "BR-CL-04")
    assert.eq(d.message, not-yet("The invoice currency code (BT-5) \"XCG\""))
    assert.eq(d.hint, not-yet-hint)
  }
  // A code of no list at all is not.
  m.currency = "XYZ"
  assert(
    diagnostic(m, "BR-CL-04").message.ends-with("is not an ISO 4217 code."),
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
