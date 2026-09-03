#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

// 1. Exclusive tax-mode with references: auto (default) -> should populate tax-nr, vat-id, recipient vat-id
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        ctx.references,
        (
          ("Steuernummer", "11/222/33333"),
          ("USt-IdNr.", "DE123456789"),
          ("Empfänger USt-IdNr.", "DE987654321"),
        ),
        message: "Exclusive tax-mode + references: auto should populate tax fallback",
      )
      body
    }),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "City",
      tax-nr: "11/222/33333",
      vat-id: "DE123456789",
    ),
    recipient: (
      name: "Recipient",
      address: "Str. 2",
      city: "City",
      vat-id: "DE987654321",
    ),
    tax-mode: "exclusive",
    references: auto,
  )[]
  [#doc]
}

// 2. Inclusive tax-mode with references: auto -> B2C, should NOT populate tax fallback (references: ())
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        ctx.references,
        (),
        message: "Inclusive tax-mode + references: auto should have empty references",
      )
      body
    }),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "City",
      tax-nr: "11/222/33333",
      vat-id: "DE123456789",
    ),
    recipient: (
      name: "Recipient",
      address: "Str. 2",
      city: "City",
      vat-id: "DE987654321",
    ),
    tax-mode: "inclusive",
    references: auto,
  )[]
  [#doc]
}

// 3. Exclusive tax-mode with references: none -> should NOT trigger tax fallback (references: ())
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        ctx.references,
        (),
        message: "references: none in exclusive mode must not trigger tax fallback",
      )
      body
    }),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "City",
      tax-nr: "11/222/33333",
      vat-id: "DE123456789",
    ),
    recipient: (
      name: "Recipient",
      address: "Str. 2",
      city: "City",
      vat-id: "DE987654321",
    ),
    tax-mode: "exclusive",
    references: none,
  )[]
  [#doc]
}

// 4. Inclusive tax-mode with references: none -> should have empty references ()
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        ctx.references,
        (),
        message: "references: none in inclusive mode must have empty references",
      )
      body
    }),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "City",
      tax-nr: "11/222/33333",
      vat-id: "DE123456789",
    ),
    recipient: (
      name: "Recipient",
      address: "Str. 2",
      city: "City",
      vat-id: "DE987654321",
    ),
    tax-mode: "inclusive",
    references: none,
  )[]
  [#doc]
}

// 5. Inclusive tax-mode with explicit references -> should retain explicit references
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        ctx.references,
        (("Kundennummer", "KD-12345"),),
        message: "Explicit references in inclusive mode should be preserved",
      )
      body
    }),
    locale: locale.de-de,
    sender: (
      name: "Sender",
      address: "Str. 1",
      city: "City",
      tax-nr: "11/222/33333",
      vat-id: "DE123456789",
    ),
    recipient: (name: "Recipient", address: "Str. 2", city: "City"),
    customer-nr: "KD-12345",
    tax-mode: "inclusive",
    references: (references.customer-nr(),),
  )[]
  [#doc]
}
