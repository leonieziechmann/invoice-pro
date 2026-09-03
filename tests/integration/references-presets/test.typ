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
          "Empfänger USt-IdNr." not in keys,
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
        assert("Empfänger USt-IdNr." in keys)
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
