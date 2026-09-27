#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale
#import "/src/utils/text.typ": plain-text

// The references as plain text: the service period is marked content.
#let plain-refs(refs) = refs.map(((label, value)) => (label, plain-text(value)))

// 1. Exclusive tax-mode with references: auto (default) -> the seller's tax
// number and VAT ID, the buyer's VAT ID and, for a seller in Germany, the
// date of the supply (§ 14 Abs. 4 Satz 1 Nr. 2 and Nr. 6 UStG): here the
// invoice date, as no item has a date
#let seller = (
  name: "Sender",
  address: "Str. 1",
  city: "City",
  tax-nr: "11/222/33333",
  vat-id: "DE123456789",
)
#let buyer = (
  name: "Recipient",
  address: "Str. 2",
  city: "City",
  vat-id: "DE987654321",
)
#let expected = (
  ("Steuernummer", "11/222/33333"),
  ("USt-IdNr.", "DE123456789"),
  ("Empfänger:in USt-IdNr.", "DE987654321"),
  ("Leistungszeitraum", "01.09.2026"),
)
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        plain-refs(ctx.references),
        expected,
        message: "Exclusive tax-mode + references: auto should populate tax fallback",
      )
      body
    }),
    locale: locale.de-de,
    sender: seller,
    recipient: buyer,
    date: datetime(year: 2026, month: 9, day: 1),
    tax-mode: "exclusive",
    references: auto,
  )[]
  [#doc]
}

// 2. Inclusive tax-mode with references: auto (B2C) -> the same: the law
// requires the seller's tax number or VAT ID and the date of the supply on
// every invoice, also with gross prices
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(
        plain-refs(ctx.references),
        expected,
        message: "Inclusive tax-mode + references: auto should print the seller's tax identifiers",
      )
      body
    }),
    locale: locale.de-de,
    sender: seller,
    recipient: buyer,
    date: datetime(year: 2026, month: 9, day: 1),
    tax-mode: "inclusive",
    references: auto,
  )[]
  [#doc]
}

// 2b. A seller outside Germany: the date of the supply only if it is given
// (Art. 226 No. 7 of the VAT Directive requires it where it differs from the
// invoice date), and the payee if it is given
#{
  let doc = invoice(
    theme: themes.blank.with(document: (ctx, body) => {
      assert.eq(plain-refs(ctx.references), (
        ("N° de TVA intra.", "FR40303265045"),
        ("Bénéficiaire du paiement", "Factor SAS"),
      ))
      body
    }),
    locale: locale.fr-fr,
    sender: (
      name: "Vendeur",
      address: "Rue 1",
      city: "75001 Paris",
      vat-id: "FR40303265045",
    ),
    recipient: (name: "Client", address: "Rue 2", city: "69001 Lyon"),
    payee: (name: "Factor SAS"),
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
