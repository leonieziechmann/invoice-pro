// The parties of the e-invoice: electronic addresses, identifiers, VAT
// identifiers, countries, post codes and the keys of the party dictionaries,
// as the data model normalizes them and the validator checks them.

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

// --- 5. Keys of the party dictionaries ---
#{
  let keys(role, ..fields) = {
    party-model(fields.named(), role: role)
      .input-keys
      .map(entry => (
        entry.path,
        entry.like,
        entry.einvoice,
      ))
  }
  // Known keys, and unset values of unknown ones, are fine
  assert.eq(keys("seller", name: "A", vat-id: "DE1", website: none), ())
  assert.eq(keys("buyer", name: "A", customer-nr: "K-1", project: "P"), ())

  // Misspellings and other names of keys the e-invoice reads
  for key in (
    "vatId",
    "vat_id",
    "VAT-ID",
    "ustid",
    "USt-IdNr",
    "vat.id",
    "numeroTva",
    "partita_iva",
  ) {
    assert.eq(
      keys("seller", ..((key): "DE123456789")),
      ((key, "vat-id", true),),
      message: key,
    )
  }
  assert.eq(keys("seller", taxnr: "1"), (("taxnr", "tax-nr", true),))
  assert.eq(keys("seller", e-mail: "a@b.de"), (("e-mail", "email", true),))
  assert.eq(keys("seller", adress: "Street 1"), (("adress", "address", true),))
  assert.eq(keys("seller", cty: "Berlin"), (("cty", "city", true),))
  assert.eq(keys("buyer", leitweg: "04011000-1234512345-06"), (
    ("leitweg", "leitweg-id", true),
  ))
  assert.eq(keys("buyer", buyer_reference: "PO-1"), (
    ("buyer_reference", "buyer-reference", true),
  ))
  // A post code belongs in `city`; next to a city line with a post code, the
  // key loses nothing
  let zip = party-model((zip: "10115"), role: "seller").input-keys.first()
  assert.eq((zip.like, zip.einvoice), ("city", true))
  assert(zip.hint.contains("city: (name: \"Berlin\", post-code: \"10115\")"))
  assert.eq(keys("seller", zip: "10115", post-code: "10115"), (
    ("zip", "city", false),
  ))
  // Other names of the VAT ID (the UID of Austria and Switzerland), of the
  // phone number and of the references of the buyer
  assert.eq(keys("seller", uid: "ATU12345678"), (("uid", "vat-id", true),))
  assert.eq(keys("seller", tel-nr: "+49 30 123456"), (
    ("tel-nr", "phone", true),
  ))
  assert.eq(keys("buyer", contract: "V-2026-01"), (
    ("contract", "contract-nr", true),
  ))
  // Keys invoices often carry, which only look like misspellings of known
  // keys ("tax-nr", "street")
  assert.eq(
    keys("seller", fax-nr: "+49 30 123457", siret: "303 265 045 00014"),
    (
      ("fax-nr", none, false),
      ("siret", none, false),
    ),
  )
  // Without `country`, a `county` is most likely a misspelled `country`; the
  // hint covers a county, which next to a `country` loses nothing
  let county = party-model((county: "Kent"), role: "buyer").input-keys.first()
  assert.eq((county.like, county.einvoice), ("country", true))
  assert(county.hint.contains("no field for a county"))
  assert.eq(keys("buyer", county: "Kent", country: "GB"), (
    ("county", "country", false),
  ))
  // Keys of `contact`; of the buyer contact, the e-invoice reads only the
  // email address
  assert.eq(keys("seller", contact: (name: "A", mail: "a@b.de")), (
    ("contact.mail", "email", true),
  ))
  assert.eq(keys("buyer", contact: (name: "A", tel: "1", mail: "a@b.de")), (
    ("contact.tel", "phone", false),
    ("contact.mail", "email", true),
  ))
  // Keys of identifiers: without `id`, the identifier would be lost
  assert.eq(keys("seller", global-id: (scheme: "0088", value: "400")), (
    ("global-id.value", none, true),
  ))
  assert.eq(keys("buyer", electronic-address: (schema: "EM", id: "a@b.de")), (
    ("electronic-address.schema", "scheme", true),
  ))
  assert.eq(keys("seller", global-id: (scheme: "0088", id: "1", note: "x")), (
    ("global-id.note", none, false),
  ))

  // Keys only the printed invoice uses, and unknown keys
  assert.eq(keys("buyer", customer_nr: "K-1"), (
    ("customer_nr", "customer-nr", false),
  ))
  assert.eq(keys("seller", website: "example.de", email2: "a@b.de"), (
    ("website", none, false),
    ("email2", none, false),
  ))
  // The delivery address takes no VAT identifier or contact
  assert.eq(keys("ship-to", vat-id: "DE123456789", email: "a@b.de"), (
    ("vat-id", none, false),
    ("email", none, false),
  ))
}

// --- 6. Validation of the parties ---
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
  assert(
    find(m, "BR-63")
      .hint
      .contains(
        "(scheme: \"0088\", id: \"4000001123452\")` for a GLN",
      ),
  )
  // A Peppol participant identifier names its scheme in front
  m.buyer.electronic-address = (
    scheme: none,
    id: "iso6523-actorid-upis::9930:DE987654321",
  )
  let hint = find(m, "BR-63").hint
  assert(
    hint.contains("(scheme: \"9930\", id: \"DE987654321\")`,"),
    message: hint,
  )
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

  // A country not stated contradicting the VAT ID (IP-COUNTRY-01)
  let m = base
  m.profile = resolve-profile("en16931", "AT")
  m.buyer = normalized(
    "buyer",
    name: "Kunde GmbH",
    city: (name: "Wien", post-code: "1010"),
    vat-id: "ATU87654321",
  )
  assert.eq(rules(m), ("IP-COUNTRY-01",))
  assert.eq(find(m, "IP-COUNTRY-01").field, "recipient.country")
  assert(find(m, "IP-COUNTRY-01").hint.contains("`country: \"AT\"`"))
  m.buyer.address.country-explicit = true
  assert.eq(rules(m), ())
  // ... for the seller as well; a foreign registration needs `country`
  let m = base
  m.seller.address.country-explicit = false
  m.seller.stated-vat-id = "EL123456789"
  assert.eq(rules(m), ("IP-COUNTRY-01",))
  m.seller.stated-vat-id = "XI123456789"
  m.seller.address.country = "GB"
  assert.eq(rules(m), ())

  // A number in the city that is no post code of the country (IP-ADDR-01)
  let m = base
  m.profile = resolve-profile("en16931", "NL")
  m.buyer = normalized(
    "buyer",
    name: "Klant BV",
    city: "1012 Amsterdam",
    country: country.nl,
    vat-id: "NL123456789B01",
  )
  assert.eq(rules(m), ("IP-ADDR-01",))
  let addr = find(m, "IP-ADDR-01")
  assert.eq(addr.field, "recipient.city")
  assert(addr.message.contains("no post code in the format of \"NL\""))
  assert(addr.hint.contains("country.custom(code: .., post-code:"))
  m.buyer.address.city = "Praha 1"
  assert.eq(rules(m), ())
  let m = base
  m.seller.address.post-code = none
  m.seller.address.city = "Berlin 10115"
  assert.eq(rules(m), ("BR-DE-4", "IP-ADDR-01"))
  assert(find(m, "BR-DE-4").hint.contains("format of the country"))

  // Keys: misspelled keys the e-invoice reads are errors, other unknown keys
  // warnings
  let m = base
  m.seller.input-keys = party-model((vatId: "DE1"), role: "seller").input-keys
  m.buyer.input-keys = party-model((website: "x"), role: "buyer").input-keys
  assert.eq(rules(m), ("IP-KEY-02",))
  assert.eq(rules(m, level: "warning"), ("IP-KEY-01",))
  let typo = find(m, "IP-KEY-02")
  assert.eq(typo.field, "sender.vatId")
  assert.eq(typo.hint, "Rename it to `vat-id`.")
  // A key only the printed invoice uses can stay
  assert(find(m, "IP-KEY-01").hint.contains("only the printed invoice"))
  let m = base
  m.seller.input-keys = party-model(
    (global-id: (scheme: "0088", value: "4000001123452")),
    role: "seller",
  ).input-keys
  assert.eq(rules(m), ("IP-KEY-02",))
  assert.eq(find(m, "IP-KEY-02").field, "sender.global-id.value")
  assert(find(m, "IP-KEY-02").message.contains("has no `id`"))

  // XRechnung: the phone number and the email address of the seller contact
  // with the patterns of the XRechnung Schematron (BR-DE-27, BR-DE-28)
  let m = base
  m.seller.contact.email = "max@müller.de"
  assert.eq(rules(m), ("BR-DE-28",))
  m.seller.contact.email = "max.muster+rechnung@xn--mller-kva.de"
  assert.eq(rules(m), ())
  m.seller.contact.email = "max@seller"
  m.seller.contact.phone = "Tel. 12"
  assert.eq(rules(m), ("BR-DE-27", "BR-DE-28"))

  // BR-CO-26 for an invoice not subject to VAT: the VAT ID is no way out
  let m = base
  m.outside-scope = true
  m.seller.vat-id = none
  m.seller.id = none
  let co26 = find(m, "BR-CO-26")
  assert(not co26.hint.contains("`vat-id`"), message: co26.hint)

  // Country codes the EN 16931 code list does not have
  let m = base
  m.buyer.address.country = "SS"
  assert(find(m, "BR-CL-14").hint.contains("South Sudan"))
  // ... but the Factur-X code list of MINIMUM and BASIC WL has South Sudan
  let basic-wl = m
  basic-wl.profile = resolve-profile("basic-wl", "SS")
  assert("BR-CL-14" not in rules(basic-wl))
  m.buyer.address.country = "EL"
  assert(find(m, "BR-CL-14").hint.contains("\"GR\""))
  m.buyer.address.country = none
  assert(find(m, "BR-11").hint.contains("`country: \"DE\"`"))

  // --- The buyer VAT ID of K and AE ---
  let with-category(model, category, lines: false, allowance: false) = {
    let model = model
    model.taxes = (
      model.taxes.first() + (category: category, rate: decimal("0")),
    )
    if lines { model.lines.at(0).category = category }
    if allowance {
      model.allowance-charges = (
        (
          charge: false,
          amount: decimal("10"),
          reason: "Discount",
          key: model.taxes.first().key,
          category: category,
          rate: decimal("0"),
        ),
      )
    }
    model.buyer.vat-id = none
    model
  }
  // Lines and document level allowances: the official rules
  assert("BR-IC-02" in rules(with-category(base, "K", lines: true)))
  assert("BR-AE-02" in rules(with-category(base, "AE", lines: true)))
  assert("BR-IC-03" in rules(with-category(base, "K", allowance: true)))
  let m = with-category(base, "AE", allowance: true)
  m.profile = resolve-profile("basic-wl", "DE")
  assert.eq(rules(m), ("BR-AE-03",))

  // BASIC WL without lines: required by law for K and a cross-border AE
  // (IP-VAT-226), not for a domestic reverse charge (§ 13b UStG)
  let m = with-category(base, "K")
  m.profile = resolve-profile("basic-wl", "DE")
  assert("IP-VAT-226" in rules(m))
  let m = with-category(base, "AE")
  m.profile = resolve-profile("basic-wl", "DE")
  assert.eq(rules(m), ())
  m.buyer.address.country = "FR"
  assert.eq(rules(m), ("IP-VAT-226",))
  assert(find(m, "IP-VAT-226").message.contains("Art. 226 No. 4"))

  // An intra-community supply to the seller's own country or to a buyer
  // outside the EU is a warning
  let m = with-category(base, "K", lines: true)
  m.buyer.vat-id = "GB123456789"
  m.ship-to = (
    name: none,
    id: none,
    global-id: none,
    address: m.buyer.address,
  )
  assert.eq(rules(m, level: "warning"), ("BR-IC-12", "IP-VAT-138"))
  m.buyer.vat-id = "XI123456789"
  m.ship-to.address.country = "GB"
  assert.eq(rules(m, level: "warning"), ())
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
