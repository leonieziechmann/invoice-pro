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
