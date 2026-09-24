// Country codes in the e-invoice: the country code list behind BR-CL-14 and
// the electronic address scheme (EAS) derived from the VAT ID prefix.

#import "/src/zugferd/guard/lists.typ": validator as lists
#import "/src/zugferd/rules/engine.typ": in-list
#import "/src/zugferd/model.typ": get-electronic-address

// --- 1. The country codes mirror the EN 16931 Schematron (BR-CL-14) ---
#{
  let countries = lists.country.every
  // South Sudan is missing in the list the official validators apply, an
  // "SS" country would make the XML invalid.
  assert(not in-list(countries, "SS"))
  // The official list has 251 codes, including the withdrawn "AN".
  assert(not in-list(countries, "AN"))
  assert.eq(countries.trim().split(" ").len(), 250)
  for code in ("DE", "FR", "GB", "XI", "1A", "NO", "FI", "CA", "JP") {
    assert(in-list(countries, code), message: code)
  }
}

// --- 2. The EAS scheme follows the VAT ID prefix, never the country ---
#{
  // A German company VAT registered in Denmark: there is no scheme for Danish
  // VAT IDs, so the email is the electronic address, not the German VAT
  // scheme 9930 with a Danish number.
  assert.eq(
    get-electronic-address((
      vat-id: "DK12345678",
      country: (code: "DE"),
      email: "billing@versand.de",
    )),
    (scheme: "EM", id: "billing@versand.de"),
  )
  assert.eq(
    get-electronic-address((vat-id: "DK12345678", country: (code: "DE"))),
    none,
  )
  // A VAT ID without country prefix gets no scheme of the party's country
  assert.eq(
    get-electronic-address((vat-id: "123456789", country: (code: "DE"))),
    none,
  )
  // A foreign VAT registration keeps the scheme of its prefix
  assert.eq(
    get-electronic-address((vat-id: "ATU12345678", country: (code: "DE"))),
    (scheme: "9914", id: "ATU12345678"),
  )
}
