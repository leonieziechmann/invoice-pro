// The party details of EN 16931 beyond names, addresses and VAT identifiers:
// legal registration identifiers (BT-30, BT-47), trading names (BT-28,
// BT-45), the additional legal information of the seller (BT-33), the buyer
// contact (BG-9), the seller tax representative (BG-11) and the payee
// (BG-10). What the model takes from the input, what the validator reports
// and where the XML states them, per profile.

#import "/src/lib.typ": *
#import "/src/logic/country.typ": normalize-party
#import "/src/zugferd/model.typ": (
  party-model, payee-model, seller-model, tax-representative-model,
)
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/rules/engine.typ": run-rules
#import "/src/zugferd/build.typ": build-xml
#import "/tests/zugferd/harness.typ": (
  buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
)

// The model switched to another profile.
#let with-profile(model, id) = model + (profile: resolve-profile(id, "FR"))

// The part of the XML from `<tag` to its end tag, or `none`.
#let element(model, tag) = xml-elements(model, tag).first(default: none)

// Whether `parts` occur in `text` in this order.
#let in-order(text, ..parts) = {
  let at = 0
  for part in parts.pos() {
    let found = text.slice(at).position(part)
    if found == none { return false }
    at += found + part.len()
  }
  true
}

#let representative(..fields) = tax-representative-model(normalize-party(
  (
    name: "Fiskal GmbH",
    address: "Steuerweg 1",
    city: "10115 Berlin",
    country: country.de,
    vat-id: "DE123456788",
  )
    + fields.named(),
  "de",
))

#let check(base) = {
  assert.eq(run-rules(base), ())

  // --- 1. Legal registration identifiers (BT-30, BT-47) ---
  // With a scheme, and without one; `seller-model` does not replace them
  // with the tax number (BR-CO-26 is satisfied)
  let legal = seller-model(
    (name: "S", tax-nr: "143/123/45678", legal-id: id.siret("12345678200010")),
  )
  assert.eq(legal.legal-id, (scheme: "0009", id: "12345678200010"))
  assert.eq(legal.id, none)
  assert.eq(party-model((legal-id: "HRB 4711")).legal-id, (
    scheme: none,
    id: "HRB 4711",
  ))
  let m = base
  m.seller.legal-id = (scheme: "0009", id: "12345678200010")
  m.buyer.legal-id = (scheme: none, id: "HRB 4711")
  let seller-xml = element(m, "ram:SellerTradeParty")
  assert(
    seller-xml.contains(
      "<ram:SpecifiedLegalOrganization><ram:ID schemeID=\"0009\">12345678200010</ram:ID></ram:SpecifiedLegalOrganization>",
    ),
    message: seller-xml,
  )
  assert(
    element(m, "ram:BuyerTradeParty").contains(
      "<ram:SpecifiedLegalOrganization><ram:ID>HRB 4711</ram:ID>",
    ),
  )
  // ... in MINIMUM as well, for the seller and the buyer
  let minimum = with-profile(m, "minimum")
  assert.eq(run-rules(minimum), ())
  assert.eq(xml-elements(minimum, "ram:SpecifiedLegalOrganization").len(), 2)

  // An ISO/IEC 6523 scheme (BR-CL-11)
  let m = base
  m.seller.legal-id = (scheme: "9999", id: "1")
  assert.eq(rules(m), ("BR-CL-11",))
  assert.eq(diagnostic(m, "BR-CL-11").field, "sender.legal-id")
  m.seller.legal-id = none
  m.buyer.legal-id = (scheme: "0204", id: "1")
  assert.eq(rules(m), ())
  m.buyer.legal-id = (scheme: "EM", id: "a@b.de")
  assert.eq(diagnostic(m, "BR-CL-11").field, "recipient.legal-id")

  // BR-CO-26: the legal registration identifier identifies the seller, also
  // in MINIMUM, where the seller has no other identifier than the VAT ID
  let m = base
  m.seller.vat-id = none
  m.seller.id = none
  assert.eq(rules(m), ("BR-CO-26",))
  assert(diagnostic(m, "BR-CO-26").hint.contains("`legal-id`"))
  m.seller.legal-id = (scheme: "0002", id: "123456782")
  assert.eq(rules(m), ())
  let minimum = with-profile(base, "minimum")
  minimum.seller.vat-id = none
  let co26 = diagnostic(minimum, "BR-CO-26")
  assert.eq(co26.field, "sender")
  assert(co26.message.contains("(BT-30)"), message: co26.message)
  assert(co26.hint.contains("`legal-id: id.siret(\"..\")`"), message: co26.hint)
  minimum.seller.legal-id = (scheme: "0009", id: "12345678200010")
  assert.eq(run-rules(minimum), ())

  // --- 2. Typed identifiers: their problems (IP-ID-01) and the business
  // term they belong to (IP-ID-03) ---
  let typed(role, ..fields) = party-model(fields.named(), role: role)
  // A party of the base model with the identifiers of `fields`.
  let with-ids(party, role, ..fields) = {
    let ids = typed(role, ..fields)
    let party = party
    for key in ("id", "global-id", "legal-id", "typed-ids") {
      party.insert(key, ids.at(key))
    }
    party
  }
  let m = base
  m.seller = with-ids(m.seller, "seller", legal-id: id.siret("12345678200011"))
  assert.eq(rules(m), ("IP-ID-01",))
  let wrong = diagnostic(m, "IP-ID-01")
  assert.eq(wrong.field, "sender.legal-id")
  assert.eq(
    wrong.message,
    "The check digit of the SIRET \"12345678200011\" is wrong.",
  )
  assert(wrong.hint.contains("`id.custom(\"0009\", ..)`"), message: wrong.hint)
  // The escape hatch: `id.custom` checks no check digit
  m.seller = with-ids(m.seller, "seller", legal-id: id.custom(
    "0009",
    "12345678200011",
  ))
  assert.eq(rules(m), ())
  // A Leitweg-ID is no party identifier, a GLN no legal registration and a
  // register number no party identifier
  for (key, value) in (
    ("legal-id", id.leitweg("991-33333TEST-33")),
    ("id", id.leitweg("991-33333TEST-33")),
    ("legal-id", id.gln("4000001123452")),
    ("id", id.register("HRB 4711")),
  ) {
    let m = base
    m.buyer = with-ids(m.buyer, "buyer", ..((key): value))
    assert.eq(rules(m), ("IP-ID-03",), message: key + ": " + repr(value))
    assert.eq(diagnostic(m, "IP-ID-03").field, "recipient." + key)
  }
  let m = base
  m.buyer.typed-ids = typed(
    "buyer",
    leitweg-id: id.gln("4000001123452"),
  ).typed-ids
  assert.eq(diagnostic(m, "IP-ID-03").field, "recipient.leitweg-id")
  // A Leitweg-ID is the buyer reference (BT-10) and an electronic address
  let leitweg = id.leitweg("04011000-1234512345-06")
  let buyer = typed("buyer", leitweg-id: leitweg, electronic-address: leitweg)
  assert.eq(buyer.typed-ids.map(entry => entry.key), (
    "electronic-address",
    "leitweg-id",
  ))
  assert.eq(buyer.electronic-address, (
    scheme: "0204",
    id: "04011000-1234512345-06",
  ))

  // --- 3. Reverse charge to a buyer without VAT ID, but with its legal
  // registration identifier (BR-AE-02; § 13b UStG) ---
  let reverse-charge(model) = {
    let model = model
    model.taxes = (
      model.taxes.first()
        + (category: "AE", rate: decimal("0"), amount: decimal("0")),
    )
    model.lines.at(0).category = "AE"
    model.buyer.vat-id = none
    model
  }
  let m = reverse-charge(base)
  assert.eq(rules(m), ("BR-AE-02",))
  assert(diagnostic(m, "BR-AE-02").message.contains("(BT-47)"))
  assert(diagnostic(m, "BR-AE-02").hint.contains("`legal-id`"))
  m.buyer.legal-id = (scheme: none, id: "HRB 4711")
  // Across a border, the law requires the buyer VAT ID all the same
  assert.eq(rules(m), ("IP-VAT-226",))
  m.buyer.address.country = "DE"
  assert.eq(rules(m), ())
  let m = with-profile(m, "basic-wl")
  assert.eq(rules(m), ())

  // --- 4. Trading names (BT-28, BT-45) and legal information (BT-33) ---
  // Given as several lines, they are joined as `info` prints them
  assert.eq(
    party-model(
      (legal-info: ("Sitz: München", [Amtsgericht München, *HRB 98765*])),
      role: "seller",
    ).legal-info,
    "Sitz: München, Amtsgericht München, HRB 98765",
  )
  let m = base
  m.seller.trading-name = "Muster Design"
  m.seller.legal-info = "Geschäftsführer: Max Muster"
  m.buyer.trading-name = "Kunde Shop"
  let seller-xml = element(m, "ram:SellerTradeParty")
  assert(
    in-order(
      seller-xml,
      "<ram:Name>",
      "<ram:Description>Geschäftsführer: Max Muster</ram:Description>",
      "<ram:SpecifiedLegalOrganization><ram:TradingBusinessName>Muster Design</ram:TradingBusinessName>",
      "<ram:DefinedTradeContact>",
      "<ram:PostalTradeAddress>",
    ),
    message: seller-xml,
  )
  assert(
    element(m, "ram:BuyerTradeParty").contains(
      "<ram:TradingBusinessName>Kunde Shop</ram:TradingBusinessName>",
    ),
  )
  assert.eq(run-rules(m), ())
  // Profiles without them leave them out and say so
  let basic = with-profile(m, "basic")
  assert.eq(rules(basic), ())
  assert.eq(rules(basic, level: "warning"), ("IP-PROFILE-01", "IP-PROFILE-01"))
  assert.eq(
    run-rules(basic).map(d => d.field),
    ("sender.legal-info", "recipient.trading-name"),
  )
  assert(not str(build-xml(basic)).contains("ram:Description"))
  assert.eq(xml-elements(basic, "ram:TradingBusinessName").len(), 1)
  let minimum = with-profile(m, "minimum")
  assert.eq(rules(minimum, level: "warning"), (
    "IP-PROFILE-01",
    "IP-PROFILE-01",
    "IP-PROFILE-01",
  ))
  assert(
    diagnostic(minimum, "IP-PROFILE-01")
      .message
      .contains("The MINIMUM profile"),
  )
  assert.eq(xml-elements(minimum, "ram:TradingBusinessName"), ())

  // --- 5. The buyer contact (BG-9) ---
  let contact(..fields) = party-model(fields.named(), role: "buyer").contact
  assert.eq(contact(contact: (name: "Frau Dupont", email: "d@b.fr")), (
    name: "Frau Dupont",
    phone: none,
    email: "d@b.fr",
  ))
  assert.eq(contact(contact-name: "Einkauf", email: "d@b.fr").email, "d@b.fr")
  assert.eq(contact(phone: "+33 1 23456789").phone, "+33 1 23456789")
  // An email address alone is where the invoice goes, not a contact
  assert.eq(contact(email: "d@b.fr"), none)
  let m = base
  m.buyer.contact = (name: "Frau Dupont", phone: none, email: "d@b.fr")
  let buyer-xml = element(m, "ram:BuyerTradeParty")
  assert(
    in-order(
      buyer-xml,
      "<ram:Name>",
      "<ram:DefinedTradeContact><ram:PersonName>Frau Dupont</ram:PersonName><ram:EmailURIUniversalCommunication><ram:URIID>d@b.fr</ram:URIID></ram:EmailURIUniversalCommunication></ram:DefinedTradeContact>",
      "<ram:PostalTradeAddress>",
    ),
    message: buyer-xml,
  )
  assert(
    not element(with-profile(m, "basic"), "ram:BuyerTradeParty").contains(
      "DefinedTradeContact",
    ),
  )

  // --- 6. The seller tax representative (BG-11) ---
  let m = base
  m.tax-representative = representative()
  assert.eq(run-rules(m), ())
  let agreement = element(m, "ram:ApplicableHeaderTradeAgreement")
  assert(
    in-order(
      agreement,
      "</ram:BuyerTradeParty>",
      "<ram:SellerTaxRepresentativeTradeParty><ram:Name>Fiskal GmbH</ram:Name><ram:PostalTradeAddress><ram:PostcodeCode>10115</ram:PostcodeCode><ram:LineOne>Steuerweg 1</ram:LineOne><ram:CityName>Berlin</ram:CityName><ram:CountryID>DE</ram:CountryID></ram:PostalTradeAddress><ram:SpecifiedTaxRegistration><ram:ID schemeID=\"VA\">DE123456788</ram:ID></ram:SpecifiedTaxRegistration></ram:SellerTaxRepresentativeTradeParty>",
    ),
    message: agreement,
  )
  // BASIC WL has it, MINIMUM not
  assert.eq(run-rules(with-profile(m, "basic-wl")), ())
  let minimum = with-profile(m, "minimum")
  assert.eq(rules(minimum), ())
  assert.eq(
    diagnostic(minimum, "IP-PROFILE-01").field,
    "sender.tax-representative",
  )
  assert.eq(xml-elements(minimum, "ram:SellerTaxRepresentativeTradeParty"), ())
  // Its VAT ID stands in for the seller's own (BR-S-02, BR-IC-02, BR-G-02),
  // but does not identify the seller (BR-CO-26)
  let m = base
  m.seller.vat-id = none
  m.seller.tax-nr = none
  m.seller.id = "SUP-70025"
  assert.eq(rules(m), ("BR-S-02",))
  assert(diagnostic(m, "BR-S-02").hint.contains("`tax-representative:"))
  m.tax-representative = representative()
  assert.eq(rules(m), ())
  m.seller.id = none
  assert.eq(rules(m), ("BR-CO-26",))
  assert(diagnostic(m, "BR-CO-26").hint.contains("tax representative"))
  for category in ("K", "G") {
    let m = base
    m.taxes.at(0).category = category
    m.taxes.at(0).rate = decimal("0")
    m.taxes.at(0).amount = decimal("0")
    m.lines.at(0).category = category
    m.seller.vat-id = none
    let rule = if category == "K" { "BR-IC-02" } else { "BR-G-02" }
    assert(rule in rules(m), message: category)
    m.tax-representative = representative()
    assert(rule not in rules(m), message: category)
  }
  // A seller without VAT identifier of its own, e.g. from Switzerland,
  // dispatches the goods of an intra-community supply from the member state
  // of its representative (BR-IC-12), and no hint takes the representative's
  // VAT identifier for the seller's `vat-id`
  let m = base
  m.taxes.at(0).category = "K"
  m.taxes.at(0).rate = decimal("0")
  m.taxes.at(0).amount = decimal("0")
  m.lines.at(0).category = "K"
  m.seller.vat-id = none
  m.seller.stated-vat-id = none
  m.seller.address.country = "CH"
  m.tax-representative = representative()
  m.ship-to = party-model(
    normalize-party(
      (
        name: "Lager",
        address: "Hafenweg 1",
        city: "60311 Frankfurt am Main",
        country: country.de,
      ),
      "de",
    ),
    role: "ship-to",
    use-vat-id: false,
  )
  let dispatch = diagnostic(m, "BR-IC-12")
  assert.ne(dispatch, none)
  assert(
    dispatch.message.contains("seller's tax representative \"DE\""),
    message: dispatch.message,
  )
  m.seller.electronic-address = none
  let address = diagnostic(m, "PEPPOL-EN16931-R020")
  assert(
    address.hint.contains("not the one of its tax representative"),
    message: address.hint,
  )
  let minimum = with-profile(m, "minimum")
  let co26 = diagnostic(minimum, "BR-CO-26").hint
  assert(co26.contains("tax representative"), message: co26)
  assert(not co26.contains("`vat-id`"), message: co26)
  // What BG-11 must state: name (BR-18), VAT ID (BR-56, BR-CO-09), country
  // (BR-20) and the address the law requires (Art. 226 No. 15)
  let m = base
  m.tax-representative = representative(name: none, vat-id: none)
  assert.eq(rules(m), ("BR-18", "BR-56"))
  assert.eq(diagnostic(m, "BR-56").field, "sender.tax-representative.vat-id")
  m.tax-representative = representative(vat-id: "123456789")
  assert.eq(rules(m), ("BR-CO-09",))
  m.tax-representative = representative(address: none, city: none)
  assert.eq(rules(m), ("IP-VAT-226",))
  assert.eq(
    diagnostic(m, "IP-VAT-226").field,
    "sender.tax-representative.address",
  )
  m.tax-representative = representative(country: none, vat-id: "ATU12345675")
  assert.eq(rules(m), ("IP-COUNTRY-01",))
  m.tax-representative.address.country = "SS"
  assert("BR-CL-14" in rules(m))
  m.tax-representative.address.country = none
  assert.eq(rules(m), ("BR-20",))
  let country = diagnostic(m, "BR-20")
  assert.eq(country.field, "sender.tax-representative.country")
  assert.eq(
    country.message,
    "The tax representative country code (BT-69) is missing.",
  )
  m.tax-representative = representative(email: "f@fiskal.de")
  assert.eq(rules(m, level: "warning"), ("IP-KEY-01",))
  // Not subject to VAT: no VAT identifiers at all (BR-O-02, see the
  // invoices not subject to VAT below)
  let m = base
  m.outside-scope = true
  m.tax-representative = representative()
  assert("BR-O-02" in rules(m))

  // --- 7. The payee (BG-10) ---
  let payee(..fields) = payee-model(fields.named())
  let m = base
  m.payee = payee(
    name: "Factor AG",
    id: id.gln("4000001123452"),
    legal-id: id.register("HRB 12345", court: "Amtsgericht Köln"),
  )
  assert.eq(run-rules(m), ())
  let settlement = element(m, "ram:ApplicableHeaderTradeSettlement")
  assert(
    in-order(
      settlement,
      "<ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>",
      "<ram:PayeeTradeParty><ram:GlobalID schemeID=\"0088\">4000001123452</ram:GlobalID><ram:Name>Factor AG</ram:Name><ram:SpecifiedLegalOrganization><ram:ID>Amtsgericht Köln, HRB 12345</ram:ID></ram:SpecifiedLegalOrganization></ram:PayeeTradeParty>",
      "<ram:SpecifiedTradeSettlementPaymentMeans>",
    ),
    message: settlement,
  )
  assert.eq(run-rules(with-profile(m, "basic-wl")), ())
  let minimum = with-profile(m, "minimum")
  assert.eq(diagnostic(minimum, "IP-PROFILE-01").field, "payee")
  assert.eq(xml-elements(minimum, "ram:PayeeTradeParty"), ())
  // Only a payee other than the seller, with a name (BR-17). BASIC WL
  // checks the name only, so there a payee that is the seller is
  // invoice-pro's own rule (IP-PAY-05)
  m.payee = payee(id: "F-1")
  assert.eq(rules(m), ("BR-17",))
  assert.eq(diagnostic(m, "BR-17").field, "payee.name")
  assert.eq(rules(with-profile(m, "basic-wl")), ("BR-17",))
  m.payee = payee(name: base.seller.name)
  assert.eq(rules(m), ("BR-17",))
  assert.eq(diagnostic(m, "BR-17").field, "payee")
  assert.eq(rules(with-profile(m, "basic")), ("BR-17",))
  let basic-wl = with-profile(m, "basic-wl")
  assert.eq(rules(basic-wl), ("IP-PAY-05",))
  assert.eq(diagnostic(basic-wl, "IP-PAY-05").field, "payee")
  // One identifier (CII-SR-451) of a known scheme (BR-CL-10, BR-CL-11)
  m.payee = payee(
    name: "Factor AG",
    id: "F-1",
    global-id: id.gln(
      "4000001123452",
    ),
  )
  assert.eq(rules(m), ("CII-SR-451",))
  m.payee = payee(
    name: "Factor AG",
    global-id: (scheme: "9999", id: "1"),
    legal-id: id.custom("9999", "1"),
  )
  assert.eq(rules(m), ("BR-CL-10", "BR-CL-11"))
  m.payee = payee(name: "Factor AG", legal-id: id.siren("123456783"))
  assert.eq(rules(m), ("IP-ID-01",))
  assert.eq(diagnostic(m, "IP-ID-01").field, "payee.legal-id")
  m.payee = payee(name: "Factor AG", iban: "DE89370400440532013000")
  assert.eq(rules(m, level: "warning"), ("IP-KEY-01",))
}

#model-test(check, sender: seller, recipient: buyer-fr)[
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

// --- 8. An invoice not subject to VAT (O) names no tax representative ---
// It states no VAT identifiers, so no tax representative, whose VAT
// identifier (BT-63) it would state: the validators report the line
// (BR-O-02), else the document level allowance (BR-O-03) or charge
// (BR-O-04). BASIC WL states no lines, so there only an allowance or charge
// breaks an official rule, and invoice-pro reports the items alone as its
// own rule (IP-TAX-05). Without its VAT identifier, the representative breaks
// BR-56 only, whose hint says to leave it out.
#let fiscal = (
  name: "Fiskal GmbH",
  address: "Steuerweg 1",
  city: (name: "Berlin", post-code: "10115"),
  country: country.de,
  vat-id: "DE123456788",
)
#let outside-scope-test(test, body) = model-test(
  test,
  sender: seller + (tax-representative: fiscal),
  recipient: buyer-fr,
)[
  #line-items[
    #item([Consulting], price: 100, tax: tax.outside-scope())
    #body
  ]
  #payment-goal(days: 14)
]
#outside-scope-test(
  model => {
    assert.eq(rules(model), ("BR-O-02",))
    assert.eq(rules(with-profile(model, "basic")), ("BR-O-02",))
    let basic-wl = with-profile(model, "basic-wl")
    assert.eq(rules(basic-wl), ("IP-TAX-05",))
    assert.eq(
      diagnostic(basic-wl, "IP-TAX-05").field,
      "sender.tax-representative",
    )
    let m = model
    m.tax-representative.vat-id = none
    for m in (m, with-profile(m, "basic-wl")) {
      assert.eq(rules(m), ("BR-56",))
      let hint = diagnostic(m, "BR-56").hint
      assert(hint.contains("leave out `tax-representative`"), message: hint)
    }
  },
  none,
)
#outside-scope-test(
  model => {
    assert.eq(rules(model), ("BR-O-02",))
    assert.eq(rules(with-profile(model, "basic-wl")), ("BR-O-03",))
  },
  discount([Rabatt], amount: 10%),
)
#outside-scope-test(
  model => {
    assert.eq(rules(model), ("BR-O-02",))
    assert.eq(rules(with-profile(model, "basic-wl")), ("BR-O-04",))
  },
  surcharge([Versand], amount: 5),
)
