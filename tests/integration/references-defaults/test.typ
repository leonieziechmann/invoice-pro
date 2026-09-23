#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

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

// 1. Exclusive tax-mode with references: auto (default) -> should populate tax-nr, vat-id, recipient vat-id
#{
  let doc = invoice(
    theme: check-references(1, refs => assert.eq(
      refs,
      (
        ("Steuernummer", "11/222/33333"),
        ("USt-IdNr.", "DE123456789"),
        ("Empfänger:in USt-IdNr.", "DE987654321"),
      ),
      message: "Exclusive tax-mode + references: auto should populate tax fallback",
    )),
    locale: locale.de-de,
    validation: none,
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
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 2. Inclusive tax-mode with references: auto -> B2C, should NOT populate tax fallback (references: ())
#{
  let doc = invoice(
    theme: check-references(2, refs => assert.eq(
      refs,
      (),
      message: "Inclusive tax-mode + references: auto should have empty references",
    )),
    locale: locale.de-de,
    validation: none,
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
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 3. Exclusive tax-mode with references: none -> should NOT trigger tax fallback (references: ())
#{
  let doc = invoice(
    theme: check-references(3, refs => assert.eq(
      refs,
      (),
      message: "references: none in exclusive mode must not trigger tax fallback",
    )),
    locale: locale.de-de,
    validation: none,
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
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 4. Inclusive tax-mode with references: none -> should have empty references ()
#{
  let doc = invoice(
    theme: check-references(4, refs => assert.eq(
      refs,
      (),
      message: "references: none in inclusive mode must have empty references",
    )),
    locale: locale.de-de,
    validation: none,
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
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// 5. Inclusive tax-mode with explicit references -> should retain explicit references
#{
  let doc = invoice(
    theme: check-references(5, refs => assert.eq(
      refs,
      (("Kundennummer", "KD-12345"),),
      message: "Explicit references in inclusive mode should be preserved",
    )),
    locale: locale.de-de,
    validation: none,
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
  )[
    #line-items[#item([Service], price: 100)]
  ]
  [#doc]
}

// Every scenario above must have run its check.
#context {
  let ran = query(<references-checked>).map(m => m.value).dedup()
  assert.eq(ran, range(1, 6), message: "checked scenarios: " + repr(ran))
}
