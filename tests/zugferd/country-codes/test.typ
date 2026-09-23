// Country codes in the e-invoice: the country code list behind BR-CL-14.

#import "/src/zugferd/codelists.typ"

// --- 1. The country codes mirror the EN 16931 Schematron (BR-CL-14) ---
#{
  // South Sudan is missing in the list the official validators apply, an
  // "SS" country would make the XML invalid.
  assert("SS" not in codelists.countries)
  // The official list has 251 codes, including the withdrawn "AN".
  assert.eq(codelists.countries.len(), 250)
  for code in ("DE", "FR", "GB", "XI", "1A", "NO", "FI", "CA", "JP") {
    assert(code in codelists.countries, message: code)
  }
}
