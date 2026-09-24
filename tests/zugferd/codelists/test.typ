// The code lists of the e-invoice validation: dictionaries of the codes of
// each list, built from lines of space-separated codes.

#import "/src/zugferd/codelists.typ"

// --- 1. Every code of the lines becomes a key, in order ---
#{
  assert.eq(
    codelists._to-set(("AE E", "G", "K L")),
    (AE: true, E: true, G: true, K: true, L: true),
  )
  assert.eq(codelists._to-set(("A",)), (A: true))
}

// --- 2. The lists contain codes only: no empty code (two spaces in a line) ---
#for (name, list) in (
  countries: codelists.countries,
  currencies: codelists.currencies,
  units: codelists.units,
  eas: codelists.eas,
  icd: codelists.icd,
  vat-categories: codelists.vat-categories,
  payment-means: codelists.payment-means,
) {
  assert.eq(type(list), dictionary, message: name)
  assert("" not in list, message: name + " contains an empty code")
  assert(list.len() > 0, message: name + " is empty")
  for (code, value) in list {
    assert(value == true and code.trim() == code, message: name + ": " + code)
  }
}

// --- 3. Lookups ---
#{
  assert("DE" in codelists.countries)
  assert("EUR" in codelists.currencies)
  assert("C62" in codelists.units)
  assert("HUR" in codelists.units)
  assert("0088" in codelists.eas)
  assert("EM" in codelists.eas)
  assert("0088" in codelists.icd)
  assert("S" in codelists.vat-categories)
  assert("de" not in codelists.countries)
  assert("C6" not in codelists.units)
  // UNTDID 4461 as EN 16931 accepts it (BR-CL-16): 84 codes, 71 to 73 and
  // 79 to 90 are not among them
  assert.eq(codelists.payment-means.len(), 84)
  for code in ("1", "10", "30", "48", "49", "54", "55", "58", "59", "ZZZ") {
    assert(code in codelists.payment-means, message: code)
  }
  for code in ("0", "058", "71", "79", "90", "99", "zzz") {
    assert(code not in codelists.payment-means, message: code)
  }
}

// --- 4. A code that the validation of a profile rejects is an error in that
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
    assert(code in codelists.currencies, message: code)
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

// --- 5. Electronic address schemes the EAS code list has withdrawn: 9901
// is no longer in the list of the EN 16931 Schematron 1.3.16 ---
#model-test(model => {
  assert("9901" not in codelists.eas)
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
