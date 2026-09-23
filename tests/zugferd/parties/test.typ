// The parties of the e-invoice: electronic addresses, identifiers and VAT
// identifiers, as the data model normalizes them and the validator checks them.

#import "/src/lib.typ": *
#import "/src/logic/country.typ": normalize-party
#import "/src/zugferd/model.typ": (
  build-model, compact, get-electronic-address, party-model, vat-id-country,
  vat-id-prefix,
)
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/validate.typ": validate
#import "/tests/data-test.typ": data-test, loom

// --- 1. Electronic addresses (BT-34, BT-49) ---
#{
  let address(..party) = get-electronic-address(party.named())

  // An address without identifier counts as not given: it is derived from the
  // VAT ID instead of writing an empty `ram:URIUniversalCommunication`
  for empty in (
    "",
    "  ",
    [],
    auto,
    none,
    (scheme: "EM"),
    (scheme: "EM", id: ""),
    (id: none),
  ) {
    assert.eq(
      address(vat-id: "FR99123456789", electronic-address: empty),
      (scheme: "9957", id: "FR99123456789"),
      message: "electronic-address: " + repr(empty),
    )
  }
  // ... or from the email, and without either there is none
  assert.eq(address(electronic-address: "", email: "ap@buyer.fr"), (
    scheme: "EM",
    id: "ap@buyer.fr",
  ))
  assert.eq(address(electronic-address: auto), none)

  // An email address needs no scheme, a scheme is a code in upper case
  assert.eq(address(electronic-address: (id: "ap@buyer.fr")), (
    scheme: "EM",
    id: "ap@buyer.fr",
  ))
  assert.eq(address(electronic-address: (scheme: "em", id: "ap@buyer.fr")), (
    scheme: "EM",
    id: "ap@buyer.fr",
  ))
  // Any other identifier keeps its missing scheme (BR-62, BR-63)
  assert.eq(address(electronic-address: "4000001123452"), (
    scheme: none,
    id: "4000001123452",
  ))

  // Invisible characters of a copied VAT ID are removed
  assert.eq(address(vat-id: "\u{200B}de 123 456\u{00AD}789\u{FEFF}"), (
    scheme: "9930",
    id: "DE123456789",
  ))
  // A VAT ID starting with a multi-byte character is no reason to crash
  assert.eq(address(vat-id: "€123456789"), none)
  assert.eq(address(vat-id: "€123456789", email: "ap@buyer.de"), (
    scheme: "EM",
    id: "ap@buyer.de",
  ))
  // Finnish VAT IDs have a scheme of their own
  assert.eq(address(vat-id: "FI12345678"), (scheme: "0213", id: "FI12345678"))
}

// --- 2. VAT identifiers: prefix and issuing country, by characters ---
#{
  assert.eq(compact("\u{200B}DE 123\u{00AD}456\u{2060}"), "DE123456")
  assert.eq(compact("\u{FEFF}"), none)
  assert.eq(vat-id-prefix("de123"), "DE")
  assert.eq(vat-id-prefix("€123"), "€1")
  assert.eq(vat-id-prefix("D"), none)
  assert.eq(vat-id-country("ATU12345678"), "AT")
  assert.eq(vat-id-country("EL123456789"), "GR")
  assert.eq(vat-id-country("XI123456789"), "GB")
  assert.eq(vat-id-country("123456789"), none)
  assert.eq(vat-id-country("€123456789"), none)
}

// --- 3. Party identifiers are never dropped ---
#{
  let ids(role: "seller", ..fields) = {
    let party = party-model(fields.named(), role: role)
    (
      id: party.id,
      global-id: party.global-id,
      id-keys: party.id-keys,
      global-id-keys: party.global-id-keys,
    )
  }
  let gln = (scheme: "0088", id: "4000001123452")

  // `id` with a scheme is a global identifier, without one an identifier
  assert.eq(ids(id: gln), (
    id: none,
    global-id: gln,
    id-keys: (),
    global-id-keys: ("id",),
  ))
  assert.eq(ids(id: (id: "SUP 1")).id, "SUP 1")
  // Spaces of a scheme identifier are formatting
  assert.eq(
    ids(global-id: (scheme: "0088", id: "4000 0011 2345 2")).global-id,
    gln,
  )
  // A global identifier without scheme is an ordinary identifier, and next to
  // `id` a second one, which the validator reports (IP-ID-02)
  assert.eq(ids(global-id: "9012345000004").id, "9012345000004")
  assert.eq(ids(id: "LIEF-0815", global-id: "9012345000004").id-keys, (
    "id",
    "global-id",
  ))
  // `location-id` is another name of `id` of the delivery address
  assert.eq(ids(role: "ship-to", location-id: "D-7").id, "D-7")
  assert.eq(ids(role: "ship-to", id: "D-7", location-id: "D-7").id-keys, (
    "id",
  ))
  assert.eq(ids(role: "ship-to", id: "D-7", location-id: "D-8").id-keys, (
    "id",
    "location-id",
  ))
  // Two identifiers with scheme
  assert.eq(
    ids(id: gln, global-id: (scheme: "0060", id: "123456789")).global-id-keys,
    ("id", "global-id"),
  )
  // Invisible characters are removed, spaces kept
  assert.eq(ids(id: "HRB\u{200B} 12345", tax-nr: "x").id, "HRB 12345")
  assert.eq(
    party-model((tax-nr: "\u{FEFF}143/123/45678")).tax-nr,
    "143/123/45678",
  )
}

// --- 4. A name of several lines is one name (BT-27, BT-44) ---
#{
  assert.eq(
    party-model((name: ("Kunde GmbH", "z. Hd. Frau Müller"))).name,
    "Kunde GmbH, z. Hd. Frau Müller",
  )
  let normalized = normalize-party(
    (name: ("Kunde GmbH", [z. Hd. *Frau* Müller]), city: "10115 Berlin"),
    "de",
    is-recipient: true,
  )
  assert.eq(
    party-model(normalized, role: "buyer").name,
    "Kunde GmbH, z. Hd. Frau Müller",
  )
}

// --- 5. Validation of the parties ---
#let rules(model, level: "error") = (
  validate(model).filter(d => d.level == level).map(d => d.rule).sorted()
)
#let find(model, rule) = validate(model).find(d => d.rule == rule)
#let normalized(role, ..fields) = party-model(
  normalize-party(fields.named(), "de", is-recipient: role != "seller"),
  role: role,
)

#let check(base) = {
  assert.eq(validate(base), ())

  // A scheme identifier is required (BR-62, BR-63), not only a known one
  let m = base
  m.seller.electronic-address = (scheme: none, id: "4000001123452")
  m.buyer.electronic-address = (scheme: none, id: "4000001123452")
  assert.eq(rules(m), ("BR-62", "BR-63"))
  assert.eq(find(m, "BR-63").field, "recipient.electronic-address")
  m.buyer.electronic-address = (scheme: "XX", id: "1")
  assert.eq(rules(m), ("BR-62", "BR-CL-25"))

  // A missing address names the input that is missing
  let m = base
  m.buyer.electronic-address = none
  m.buyer.stated-vat-id = "DK12345678"
  let missing = find(m, "PEPPOL-EN16931-R010")
  assert(missing.hint.contains("prefix \"DK\""), message: missing.hint)
  assert(not missing.hint.contains("`vat-id`"), message: missing.hint)
  m.buyer.stated-vat-id = none
  assert(find(m, "PEPPOL-EN16931-R010").hint.contains("`vat-id`"))

  // Identifiers: two values for one slot, the buyer and the ship-to party
  // with one identifier only (CII-SR-450, CII-SR-449), scheme lists
  let m = base
  let ids = party-model((id: "C-1", global-id: "4000001123452"))
  for key in ("id", "global-id", "id-keys", "global-id-keys") {
    m.buyer.insert(key, ids.at(key))
  }
  assert.eq(rules(m), ("IP-ID-02",))
  assert.eq(find(m, "IP-ID-02").field, "recipient.global-id")
  let m = base
  m.buyer.id = "C-1"
  m.buyer.global-id = (scheme: "0088", id: "4000001123452")
  assert.eq(rules(m), ("CII-SR-450",))
  m.profile = resolve-profile("basic-wl", "DE")
  assert.eq(rules(m), ())
  let m = base
  m.ship-to = normalized(
    "ship-to",
    name: "Lager",
    city: "10115 Berlin",
    location-id: "LAGER-7",
    global-id: (scheme: "0088", id: "4000001123452"),
  )
  assert.eq(rules(m), ("CII-SR-449",))
  m.ship-to.id = none
  m.ship-to.global-id = (scheme: "9999", id: "1")
  assert.eq(rules(m), ("BR-CL-26",))
  m.ship-to.id-keys = ("id", "location-id")
  assert.eq(rules(m), ("BR-CL-26", "IP-ID-02"))

  // The VAT ID prefix is checked by characters (BR-CO-09)
  let m = base
  m.seller.vat-id = "€123456789"
  assert.eq(rules(m), ("BR-CO-09",))

  // BR-CO-26 for an invoice not subject to VAT: the VAT ID is no way out
  let m = base
  m.outside-scope = true
  m.seller.vat-id = none
  m.seller.id = none
  let co26 = find(m, "BR-CO-26")
  assert(not co26.hint.contains("`vat-id`"), message: co26.hint)
}

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@seller.de",
    ),
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    email: "accounting@buyer.de",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#data-test(test: (ctx, data) => {
  let signal(kind) = loom.query.find-signal(data, kind)
  let model = build-model(
    ctx,
    signal("line-items").item-data,
    payment-goal: signal("payment-goal"),
    bank: signal("bank-details"),
  )
  assert.eq(model.profile.id, "xrechnung")
  check(model)
})[
  #line-items[
    #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
  ]
  #payment-goal(days: 14)
  #bank-details(
    bank: "Musterbank",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )
]
