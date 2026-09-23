// The rules of the VAT categories as each profile applies them: the rates of
// IPSI (M) and of items not subject to VAT (O), the identifiers of the
// parties in BASIC WL, which has no lines, an invoice without a VAT
// breakdown, margin schemes and items without any tax (`tax: none`).

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, buyer-fr, diagnostic, model-test, rules, seller,
)

// A seller that states only its tax number, and one with an identifier only.
#let seller-tax-nr = seller + (vat-id: none)
#let seller-id = seller + (vat-id: none, tax-nr: none, id: "SUP-1")
#let buyer-at = (
  name: "Käufer GmbH",
  address: "Gasse 3",
  city: (name: "Wien", post-code: "1010"),
  country: country.at,
)
#let buyer-ch = (
  name: "Kunde AG",
  address: "Weg 1",
  city: (name: "Zürich", post-code: "8001"),
  country: country.ch,
)

// --- 1. IPSI (M) needs a rate above 0% (BR-AG-05), also on document level
// allowances and charges (BR-AG-06, BR-AG-07) ---
#model-test(tax: tax.special.ceuta-melilla(0%), model => {
  assert.eq(rules(model), ("BR-AG-05",))
  assert.eq(
    diagnostic(model, "BR-AG-05").message,
    "The IPSI category (M) needs a rate above 0%.",
  )
  // BASIC WL has no lines, but the rule of allowances applies
  let m = model
  m.profile = resolve-profile("basic-wl", "FR")
  assert.eq(rules(m), ("BR-AG-06",))
})[
  #line-items[
    #item([Leistung], price: 100)
    #discount([Rabatt], amount: 5%)
  ]
  #payment-goal(days: 14)
  #bank
]

#model-test(tax: tax.special.ceuta-melilla(4%), model => {
  assert.eq(rules(model), ())
})[
  #line-items[#item([Leistung], price: 100)]
  #payment-goal(days: 14)
  #bank
]

// --- 2. Items not subject to VAT (O) carry no VAT (BR-O-09) ---
#model-test(
  tax: tax.new(rate: 19%, category: "O", grounds: "Nicht steuerbar"),
  model => {
    assert.eq(rules(model), ("BR-O-09",))
  },
)[
  #line-items[#item([Leistung], price: 100)]
  #payment-goal(days: 14)
  #bank
]

// --- 3. BASIC WL has no lines: the rules of the lines' categories do not
// apply there, those of document level allowances and charges do ---
// An export by a seller with a tax number only: valid in BASIC WL ...
#model-test(
  zugferd: "basic-wl",
  sender: seller-tax-nr,
  recipient: buyer-ch,
  tax: tax.export(),
  model => {
    assert.eq(rules(model), ())
    // ... but not with an export discount (BR-G-03) ...
    let m = model
    m.allowance-charges = (
      (
        charge: false,
        amount: decimal("5"),
        reason: "Rabatt",
        key: model.taxes.first().key,
        category: "G",
        rate: decimal("0"),
      ),
    )
    assert.eq(rules(m), ("BR-G-03",))
    // ... and not with lines (BR-G-02)
    let m = model
    m.profile = resolve-profile("en16931", "CH")
    assert.eq(rules(m), ("BR-G-02",))
  },
)[
  #line-items[#item([Maschine], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// VAT charged by a seller with an identifier only
#model-test(zugferd: "basic-wl", sender: seller-id, model => {
  assert.eq(rules(model), ())
  let m = model
  m.profile = resolve-profile("basic", "FR")
  assert.eq(rules(m), ("BR-S-02",))
})[
  #line-items[#item([Leistung], price: 100)]
  #payment-goal(days: 14)
  #bank
]

#model-test(zugferd: "basic-wl", sender: seller-id, model => {
  assert.eq(rules(model), ("BR-S-04",))
  assert(
    diagnostic(model, "BR-S-04")
      .message
      .starts-with(
        "Document level charges with the VAT category S require",
      ),
  )
})[
  #line-items[
    #item([Leistung], price: 100)
    #surcharge([Versand], amount: 4.90)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 4. The buyer VAT ID of an intra-community supply or a cross-border
// reverse charge is required by law, also in BASIC WL (IP-VAT-226); a
// domestic reverse charge (e.g. § 13b UStG) does not need it ---
#model-test(
  zugferd: "basic-wl",
  recipient: buyer-de + (vat-id: none),
  tax: tax.reverse-charge(
    grounds: "Steuerschuldnerschaft des Leistungsempfängers",
  ),
  model => {
    assert.eq(rules(model), ())
    let m = model
    m.buyer.address.country = "AT"
    assert.eq(rules(m), ("IP-VAT-226",))
    // With lines, EN 16931 requires it in any case (BR-AE-02)
    let m = model
    m.profile = resolve-profile("en16931", "DE")
    assert.eq(rules(m), ("BR-AE-02",))
  },
)[
  #line-items[#item([Bauleistung], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

#model-test(
  zugferd: "basic-wl",
  recipient: buyer-at,
  tax: tax.intra-community(),
  model => {
    assert.eq(rules(model), ("IP-VAT-226",))
    assert.eq(
      diagnostic(model, "IP-VAT-226").message,
      "An intra-community supply (K) must state the buyer VAT identifier (BT-48) by law (Art. 226 No. 4 of the VAT Directive 2006/112/EC).",
    )
  },
)[
  #line-items[#item([Maschine], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 5. An invoice without items has no VAT breakdown (BR-CO-18) ---
#model-test(zugferd: "basic-wl", model => {
  assert.eq(rules(model), ("BR-CO-18",))
})[
  #line-items[]
  #payment-goal(days: 14)
  #bank
]

// --- 6. Margin schemes are written as exempt with the note the law requires ---
#model-test(tax: tax.special.margin-second-hand(19%), model => {
  assert.eq(rules(model), ("BR-CL-18",))
  assert(
    diagnostic(model, "BR-CL-18")
      .hint
      .contains(
        "`tax.exempt(grounds: \"Margin scheme - second-hand goods\")`",
      ),
  )
})[
  #line-items[#item([Gebrauchtwagen], price: 10000)]
  #payment-goal(days: 14)
  #bank
]

// --- 7. `tax: none` does not say which VAT category applies (IP-TAX-01) ---
#model-test(tax: none, model => {
  assert.eq(model.lines.map(l => l.category), ("Z", "Z"))
  assert.eq(rules(model), ("IP-TAX-01",))
  let d = diagnostic(model, "IP-TAX-01")
  assert.eq(d.field, "tax")
  assert.eq(
    d.message,
    "The invoice sets `tax: none`, so 2 items have no VAT category (BT-151): printed with 0%, it would be declared as zero rated (Z).",
  )
  // Also in MINIMUM, which states the VAT total only
  let m = model
  m.profile = resolve-profile("minimum", "FR")
  assert.eq(rules(m), ("IP-TAX-01",))
})[
  #line-items[
    #item([A], price: 100)
    #item([B], price: 100)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 8. A VAT group without category is an error of its own; the other
// checks still run instead of stopping the compilation ---
#model-test(model => {
  let m = model
  m.taxes.at(0).category = none
  assert.eq(rules(m), ("BR-CL-18",))
  m.taxes.at(0).rate = decimal("0.1912345")
  assert.eq(rules(m), ("BR-CL-18", "IP-DEC-01"))
  assert.eq(
    diagnostic(m, "IP-DEC-01").message,
    "The VAT rate 19.12345% has more than 4 decimals, so the e-invoice would state it as 19.1235%.",
  )
})[
  #line-items[#item([A], price: 100)]
  #payment-goal(days: 14)
  #bank
]
