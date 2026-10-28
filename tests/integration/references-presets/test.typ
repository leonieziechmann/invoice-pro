#import "/src/lib.typ": *

// Checks the normalized references core hands to the frame (`view.references`).
// The plain layout hosts no references row, so its empty standard
// `references` area hosts the `references` part, replaced by a check that
// then renders the default part. Every check records its scenario `id`.
//
// The scenarios use minimal invoice data, so they render without validation
// feedback (`validation: none`): the feedback is not what these checks are about.
#let check-references(id, check) = theme.plain.with(
  theme.custom.area("references", parts: ("references",)),
  theme.custom.part("references", (ctx, view) => {
    check(view.references)
    [#metadata(id)<references-checked>]
    theme.parts.references(ctx, view)
  }),
)

// 1. preset-b2b() with only vat-id: should include vat-id, omit tax-nr and recipient-vat-id
#{
  let doc = invoice(
    theme: check-references(1, refs => {
      let keys = refs.map(r => r.at(0))
      assert(
        "USt-IdNr." in keys,
        message: "vat-id should be present in preset-b2b() when specified",
      )
      assert(
        "Steuernummer" not in keys,
        message: "tax-nr should be omitted from preset-b2b() when not specified",
      )
      assert(
        "Empfänger:in USt-IdNr." not in keys,
        message: "recipient-vat-id should be omitted from preset-b2b() when not specified",
      )
    }),
    locale: locale.de-de,
    validation: none,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      vat-id: "DE123456789",
    ),
    recipient: (name: "Recipient", address: "Str. 2", city: "Paris"),
    invoice-nr: "INV-001",
    references: references.preset-b2b(),
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 2. preset-b2b() with only tax-nr: should include tax-nr, omit vat-id
#{
  let doc = invoice(
    theme: check-references(2, refs => {
      let keys = refs.map(r => r.at(0))
      assert(
        "Steuernummer" in keys,
        message: "tax-nr should be present in preset-b2b() when specified",
      )
      assert(
        "USt-IdNr." not in keys,
        message: "vat-id should be omitted from preset-b2b() when not specified",
      )
    }),
    locale: locale.de-de,
    validation: none,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      tax-nr: "11/222/33333",
    ),
    recipient: (name: "Recipient", address: "Str. 2", city: "Paris"),
    invoice-nr: "INV-002",
    references: references.preset-b2b(),
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 3. preset-b2b() with both tax-nr, vat-id, and recipient vat-id: should include all three
#{
  let doc = invoice(
    theme: check-references(3, refs => {
      let keys = refs.map(r => r.at(0))
      assert("Steuernummer" in keys)
      assert("USt-IdNr." in keys)
      assert("Empfänger:in USt-IdNr." in keys)
    }),
    locale: locale.de-de,
    validation: none,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      tax-nr: "11/222/33333",
      vat-id: "DE123456789",
    ),
    recipient: (
      name: "Recipient",
      address: "Str. 2",
      city: "Paris",
      vat-id: "FR987654321",
    ),
    invoice-nr: "INV-003",
    references: references.preset-b2b(),
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 4. preset-b2b() with empty string values: should omit empty fields
#{
  let doc = invoice(
    theme: check-references(4, refs => {
      let keys = refs.map(r => r.at(0))
      assert("USt-IdNr." in keys)
      assert(
        "Steuernummer" not in keys,
        message: "empty string tax-nr should not be included in references",
      )
    }),
    locale: locale.de-de,
    validation: none,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      tax-nr: "",
      vat-id: "DE123456789",
    ),
    recipient: (name: "Recipient", address: "Str. 2", city: "Paris"),
    invoice-nr: "INV-004",
    references: references.preset-b2b(),
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 5. preset-b2g() with tax IDs and buyer-reference
#{
  let doc = invoice(
    theme: check-references(5, refs => {
      let keys = refs.map(r => r.at(0))
      assert("USt-IdNr." in keys)
      assert("Leitweg-ID / Referenz" in keys)
    }),
    locale: locale.de-de,
    validation: none,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      vat-id: "DE123456789",
    ),
    recipient: (
      name: "City of Berlin",
      address: "Str. 2",
      city: "Berlin",
      buyer-reference: "04011000-12345-67",
    ),
    invoice-nr: "INV-005",
    references: references.preset-b2g(),
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 6. preset-project() with tax IDs and project name
#{
  let doc = invoice(
    theme: check-references(6, refs => {
      let keys = refs.map(r => r.at(0))
      assert("USt-IdNr." in keys)
      assert("Projekt" in keys)
    }),
    locale: locale.de-de,
    validation: none,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      vat-id: "DE123456789",
    ),
    recipient: (name: "Client", address: "Str. 2", city: "Berlin"),
    project: "Alpha Project",
    invoice-nr: "INV-006",
    references: references.preset-project(),
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 7. Every preset states what the law requires on the invoice (§ 14 Abs. 4
// UStG, Art. 226 of the VAT Directive): the date of the supply, the seller's
// tax number and VAT ID and the buyer's VAT ID. On a self-billed invoice, the
// buyer issues it: the seller is the recipient, whose tax number and VAT ID
// are printed, and the buyer the sender. The payee is printed if given.
#let check-preset(preset, index) = {
  let check(labels, expected) = {
    for label in expected {
      assert(label in labels, message: repr(label) + " in " + repr(labels))
    }
  }
  // A document that checks the labels and values of its references
  let refs(id, ..args) = {
    invoice(
      theme: check-references(id, refs => {
        check(refs.map(r => r.first()), args.named().at("expect"))
        let values = refs.map(r => r.last())
        for value in args.named().at("values", default: ()) {
          assert(value in values, message: repr(value) + " in " + repr(values))
        }
      }),
      locale: locale.de-de,
      validation: none,
      document-type: args.named().at("document-type", default: auto),
      sender: (
        name: "Sender",
        address: "Str. 1",
        city: "10115 Berlin",
        tax-nr: "11/222/33333",
        vat-id: "DE123456789",
      ),
      recipient: (
        name: "Recipient",
        address: "Str. 2",
        city: "75001 Paris",
        country: country.fr,
        tax-nr: "303265045",
        vat-id: "FR40303265045",
      ),
      payee: args.named().at("payee", default: none),
      invoice-nr: "INV-007",
      references: preset(),
    )[
      #line-items[#item([Service], price: 100)]
    ]
  }
  let id(n) = "7." + str(index) + "." + str(n)
  [#refs(
    id(1),
    expect: (
      "Leistungszeitraum",
      "Steuernummer",
      "USt-IdNr.",
      "Empfänger:in USt-IdNr.",
    ),
    values: ("11/222/33333", "DE123456789", "FR40303265045"),
  )]
  [#refs(
    id(2),
    document-type: "self-billed",
    expect: (
      "Empfänger:in Steuernummer",
      "Empfänger:in USt-IdNr.",
      "USt-IdNr.",
    ),
    values: ("303265045", "FR40303265045", "DE123456789"),
  )]
  [#refs(
    id(3),
    payee: (name: "Factoring Bank AG"),
    expect: ("Zahlungsempfänger",),
    values: ("Factoring Bank AG",),
  )]
}
#for (index, preset) in (
  references.preset-b2b,
  references.preset-b2g,
  references.preset-project,
  references.preset-din-5008,
).enumerate() {
  check-preset(preset, index + 1)
}

// Every scenario above must have run its check.
#context {
  let ran = query(<references-checked>).map(m => m.value).dedup()
  let expected = (
    range(1, 7)
      + range(1, 5)
        .map(p => range(1, 4).map(n => "7." + str(p) + "." + str(n)))
        .flatten()
  )
  assert.eq(ran, expected, message: "checked scenarios: " + repr(ran))
}
