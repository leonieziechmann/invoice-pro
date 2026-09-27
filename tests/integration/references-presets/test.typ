#import "/src/lib.typ": *

// 1. preset-b2b() with only vat-id: should include vat-id, omit tax-nr and recipient-vat-id
#{
  let doc = invoice(
    theme: themes.blank.with(
      document: (ctx, body) => {
        let keys = ctx.references.map(r => r.at(0))
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
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      vat-id: "DE123456789",
    ),
    recipient: (name: "Recipient", address: "Str. 2", city: "Paris"),
    invoice-nr: "INV-001",
    references: references.preset-b2b(),
  )[]
  [#doc]
}

// 2. preset-b2b() with only tax-nr: should include tax-nr, omit vat-id
#{
  let doc = invoice(
    theme: themes.blank.with(
      document: (ctx, body) => {
        let keys = ctx.references.map(r => r.at(0))
        assert(
          "Steuernummer" in keys,
          message: "tax-nr should be present in preset-b2b() when specified",
        )
        assert(
          "USt-IdNr." not in keys,
          message: "vat-id should be omitted from preset-b2b() when not specified",
        )
        body
      },
    ),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "Berlin",
      tax-nr: "11/222/33333",
    ),
    recipient: (name: "Recipient", address: "Str. 2", city: "Paris"),
    invoice-nr: "INV-002",
    references: references.preset-b2b(),
  )[]
  [#doc]
}

// 3. preset-b2b() with both tax-nr, vat-id, and recipient vat-id: should include all three
#{
  let doc = invoice(
    theme: themes.blank.with(
      document: (ctx, body) => {
        let keys = ctx.references.map(r => r.at(0))
        assert("Steuernummer" in keys)
        assert("USt-IdNr." in keys)
        assert("Empfänger:in USt-IdNr." in keys)
        body
      },
    ),
    locale: locale.de-de,
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
  )[]
  [#doc]
}

// 4. preset-b2b() with empty string values: should omit empty fields
#{
  let doc = invoice(
    theme: themes.blank.with(
      document: (ctx, body) => {
        let keys = ctx.references.map(r => r.at(0))
        assert("USt-IdNr." in keys)
        assert(
          "Steuernummer" not in keys,
          message: "empty string tax-nr should not be included in references",
        )
        body
      },
    ),
    locale: locale.de-de,
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
  )[]
  [#doc]
}

// 5. preset-b2g() with tax IDs and buyer-reference
#{
  let doc = invoice(
    theme: themes.blank.with(
      document: (ctx, body) => {
        let keys = ctx.references.map(r => r.at(0))
        assert("USt-IdNr." in keys)
        assert("Leitweg-ID / Referenz" in keys)
        body
      },
    ),
    locale: locale.de-de,
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
  )[]
  [#doc]
}

// 6. preset-project() with tax IDs and project name
#{
  let doc = invoice(
    theme: themes.blank.with(
      document: (ctx, body) => {
        let keys = ctx.references.map(r => r.at(0))
        assert("USt-IdNr." in keys)
        assert("Projekt" in keys)
        body
      },
    ),
    locale: locale.de-de,
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
  )[]
  [#doc]
}

// 7. Every preset states what the law requires on the invoice (§ 14 Abs. 4
// UStG, Art. 226 of the VAT Directive): the date of the supply, the seller's
// tax number and VAT ID and the buyer's VAT ID. On a self-billed invoice, the
// buyer issues it: the seller is the recipient, whose tax number and VAT ID
// are printed, and the buyer the sender. The payee is printed if given.
#let check-preset(preset) = {
  let check(labels, expected) = {
    for label in expected {
      assert(label in labels, message: repr(label) + " in " + repr(labels))
    }
  }
  // A document that checks the labels and values of its references
  let refs(..args) = {
    invoice(
      theme: themes.blank.with(document: (ctx, body) => {
        check(ctx.references.map(r => r.first()), args.named().at("expect"))
        let values = ctx.references.map(r => r.last())
        for value in args.named().at("values", default: ()) {
          assert(value in values, message: repr(value) + " in " + repr(values))
        }
        body
      }),
      locale: locale.de-de,
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
    )[]
  }
  [#refs(
    expect: (
      "Leistungszeitraum",
      "Steuernummer",
      "USt-IdNr.",
      "Empfänger:in USt-IdNr.",
    ),
    values: ("11/222/33333", "DE123456789", "FR40303265045"),
  )]
  [#refs(
    document-type: "self-billed",
    expect: (
      "Empfänger:in Steuernummer",
      "Empfänger:in USt-IdNr.",
      "USt-IdNr.",
    ),
    values: ("303265045", "FR40303265045", "DE123456789"),
  )]
  [#refs(
    payee: (name: "Factoring Bank AG"),
    expect: ("Zahlungsempfänger",),
    values: ("Factoring Bank AG",),
  )]
}
#for preset in (
  references.preset-b2b,
  references.preset-b2g,
  references.preset-project,
  references.preset-din-5008,
) {
  check-preset(preset)
}
