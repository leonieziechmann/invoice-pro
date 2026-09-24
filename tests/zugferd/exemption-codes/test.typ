// The VAT exemption reason code (BT-121, CEF VATEX code list) next to the
// exemption reason text (BT-120): the code of the category for an
// intra-community supply (K), a reverse charge (AE), an export (G) and items
// not subject to VAT (O), a code of one's own with `code` (e.g. for an
// exemption, E), and the checks that it is a code of the list (BR-CL-22) and
// fits its category (IP-TAX-02 to IP-TAX-04).

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
  xml-values,
)

#let buyer-ch = (
  name: "Kunde AG",
  address: "Weg 1",
  city: (name: "Zürich", post-code: "8001"),
  country: country.ch,
)
#let items(..args) = [
  #line-items[#item([Leistung], price: 100, ..args)]
  #payment-goal(days: 14)
  #bank
]
// The codes of the VAT breakdown (BG-23), in the order of the XML.
#let codes(model) = model.taxes.map(tax => tax.code)

// --- 1. The code of the category (K, AE, G, O) ---
#for (category-tax, recipient, code) in (
  (tax.intra-community(), buyer-fr, "VATEX-EU-IC"),
  (tax.reverse-charge(), buyer-fr, "VATEX-EU-AE"),
  (tax.export(), buyer-ch, "VATEX-EU-G"),
  (tax.outside-scope(), buyer-de, "VATEX-EU-O"),
) {
  model-test(tax: category-tax, recipient: recipient, model => {
    assert.eq(codes(model), (code,))
    // The text of the reason stays (BT-120)
    assert.ne(model.taxes.first().reason, none)
    // After the category code, before the rate (XSD order)
    let tax-element = xml-elements(model, "ram:ApplicableTradeTax").last()
    assert(
      tax-element.contains(
        "</ram:CategoryCode><ram:ExemptionReasonCode>"
          + code
          + "</ram:ExemptionReasonCode><ram:RateApplicablePercent>",
      ),
      message: tax-element,
    )
    assert.eq(rules(model), ())
    // From BASIC WL on; MINIMUM has no VAT breakdown
    let m = model
    m.profile = resolve-profile("basic-wl", "DE")
    assert.eq(xml-values(m, "ram:ExemptionReasonCode"), (code,))
  })[#items()]
}

// Standard rated and zero rated items have no exemption reason, and an
// exemption none of its own
#model-test(model => {
  assert.eq(codes(model), (none,))
  assert.eq(xml-values(model, "ram:ExemptionReasonCode"), ())
})[#items()]
#model-test(tax: tax.zero(), model => assert.eq(codes(model), (none,)))[
  #items()
]
#model-test(
  tax: tax.exempt(grounds: "Steuerfrei nach § 4 Nr. 21 UStG"),
  model => {
    assert.eq(codes(model), (none,))
    assert.eq(rules(model), ())
  },
)[#items()]

// --- 2. A code of one's own, in any case and with spaces ---
#model-test(
  tax: tax.exempt(
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
    code: " vatex-eu-132-1c ",
  ),
  model => {
    assert.eq(codes(model), ("VATEX-EU-132-1C",))
    assert.eq(model.taxes.first().reason, "Steuerfrei nach § 4 Nr. 14 UStG")
    assert.eq(xml-values(model, "ram:ExemptionReasonCode"), (
      "VATEX-EU-132-1C",
    ))
    assert.eq(rules(model), ())
    assert.eq(rules(model, level: "warning"), ())
  },
)[#items()]
// ... also instead of the code of the category
#model-test(
  tax: tax.reverse-charge(code: "VATEX-EU-AE"),
  recipient: buyer-fr,
  model => assert.eq(codes(model), ("VATEX-EU-AE",)),
)[#items()]
// ... on an item, a bundle and a modifier
#model-test(model => {
  assert.eq(codes(model).filter(c => c != none), ("VATEX-EU-132-1C",))
  assert.eq(codes(model).len(), 2)
  assert.eq(rules(model), ())
})[
  #line-items[
    #item([Leistung], price: 100)
    #item([Heilbehandlung], price: 50, tax: tax.exempt(
      grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
      code: "VATEX-EU-132-1C",
    ))
  ]
  #payment-goal(days: 14)
  #bank
]
#model-test(model => {
  assert.eq(codes(model).filter(c => c != none), ("VATEX-EU-132-1C",))
  assert.eq(codes(model).len(), 2)
})[
  #line-items[
    #bundle([Paket])[
      #item([Leistung], price: 100)
      #item([Heilbehandlung], price: 50, tax: tax.exempt(
        grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
        code: "VATEX-EU-132-1C",
      ))
    ]
  ]
  #payment-goal(days: 14)
  #bank
]
#model-test(model => {
  assert.eq(codes(model).filter(c => c != none), ("VATEX-EU-132-1C",))
  assert.eq(codes(model).len(), 2)
})[
  #line-items[
    #item([Leistung], price: 100)
    #surcharge([Gutachten], amount: 20, tax: tax.exempt(
      grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
      code: "VATEX-EU-132-1C",
    ))
  ]
  #payment-goal(days: 14)
  #bank
]

// The small business scheme of France has a code of its own
#model-test(
  locale: locale.fr-fr,
  sender: seller + (country: country.fr, vat-id: none, tax-nr: none, id: "S1"),
  recipient: buyer-fr,
  tax-exempt-small-biz: true,
  model => {
    assert.eq(codes(model), ("VATEX-FR-FRANCHISE",))
    assert.eq(model.taxes.first().category, "E")
  },
)[#items()]

// --- 3. The code must be one of the VATEX list (BR-CL-22) ---
#model-test(
  tax: tax.exempt(grounds: "Steuerfrei", code: "VATEX-EU-999"),
  model => {
    assert.eq(rules(model), ("BR-CL-22",))
    let d = diagnostic(model, "BR-CL-22")
    assert.eq(d.field, "tax E 0%")
    assert.eq(
      d.message,
      "The VAT exemption reason code (BT-121) \"VATEX-EU-999\" is not a code of the VATEX code list.",
    )
    // BASIC WL checks it with the list of the Factur-X Schematron
    let m = model
    m.profile = resolve-profile("basic-wl", "DE")
    assert.eq(rules(m), ("FX-SCH-A-000181",))
    assert.eq(diagnostic(m, "FX-SCH-A-000181").message, d.message)
  },
)[#items()]
// A code only the newer list of the KoSIT validator knows: Mustang and the
// Factur-X code list reject it, so the message says that it is not known
// there yet
#model-test(
  tax: tax.exempt(grounds: "Steuerfrei", code: "VATEX-EU-144"),
  model => {
    assert.eq(rules(model), ("BR-CL-22",))
    let d = diagnostic(model, "BR-CL-22")
    assert.eq(
      d.message,
      "The VAT exemption reason code (BT-121) \"VATEX-EU-144\" is not in the code list of the Factur-X validation yet: only the newest version of the EN 16931 code list has it.",
    )
    assert.eq(
      d.hint,
      "Use another code while the validators of the Factur-X profiles do not know it yet.",
    )
  },
)[#items()]

// --- 4. ... and fit its category (IP-TAX-02) ---
#model-test(
  tax: tax.exempt(grounds: "Steuerfrei", code: "VATEX-EU-IC"),
  model => {
    assert.eq(rules(model), ("IP-TAX-02",))
    assert.eq(
      diagnostic(model, "IP-TAX-02").message,
      "The VAT exemption reason code (BT-121) \"VATEX-EU-IC\" is a code of the VAT category K, not of E, so the e-invoice would state another reason than its category.",
    )
  },
)[#items()]
#model-test(
  tax: tax.intra-community(code: "VATEX-EU-132"),
  recipient: buyer-fr,
  model => assert.eq(rules(model), ("IP-TAX-02",)),
)[#items()]
// A taxed category has none: it is not written
#model-test(
  tax: tax.new(rate: 19%, category: "S", code: "VATEX-EU-132"),
  model => {
    assert.eq(rules(model), ("IP-TAX-02",))
    assert(
      diagnostic(model, "IP-TAX-02")
        .message
        .ends-with(
          "cannot be stated for the VAT category S, which is not exempt: it has no exemption reason.",
        ),
    )
    assert.eq(codes(model), (none,))
    assert.eq(xml-values(model, "ram:ExemptionReasonCode"), ())
  },
)[#items()]

// --- 5. One code per VAT category and rate (IP-TAX-03) ---
#model-test(model => {
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ("IP-TAX-03",))
  // The reasons are stated as text
  assert.eq(codes(model), (none,))
  assert.eq(
    model.taxes.first().reason,
    "Steuerfrei nach § 4 Nr. 14 UStG; Steuerfrei nach § 4 Nr. 21 UStG",
  )
})[
  #line-items[
    #item([Heilbehandlung], price: 50, tax: tax.exempt(
      grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
      code: "VATEX-EU-132-1C",
    ))
    #item([Unterricht], price: 50, tax: tax.exempt(
      grounds: "Steuerfrei nach § 4 Nr. 21 UStG",
      code: "VATEX-EU-132-1I",
    ))
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 6. An exemption with a code needs its text as well (IP-TAX-04) ---
#model-test(tax: tax.exempt(code: "VATEX-EU-132-1C"), model => {
  assert.eq(rules(model), ("IP-TAX-04",))
  assert(
    diagnostic(model, "IP-TAX-04")
      .message
      .starts-with(
        "Exempt items (E) with the VAT exemption reason code \"VATEX-EU-132-1C\" (BT-121) need the exemption reason as text as well",
      ),
  )
})[#items()]
// Without either, the official rule applies (BR-E-10)
#model-test(tax: tax.exempt(), model => {
  assert.eq(rules(model), ("BR-E-10",))
})[#items()]

// --- 7. `code` is a string ---
#assert.eq(
  catch(() => tax.exempt(code: 132)),
  "assertion failed: tax: `code` must be a VAT exemption reason code of the VATEX code list such as \"VATEX-EU-132-1A\", got 132.",
)
