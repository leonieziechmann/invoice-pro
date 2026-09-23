// The notes of an invoice (`notes`): printed below the line items and
// written into the e-invoice as BT-22 with their line breaks and the
// optional subject code BT-21 (BR-CL-08), from BASIC WL on.

#import "/src/lib.typ": *
#import "/src/logic/notes.typ": normalize-notes
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/utils/text.typ": plain-text
#import "/tests/zugferd/harness.typ": (
  bank, buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
)

// --- 1. The input: a text, or an array of texts and dictionaries ---
#{
  assert.eq(normalize-notes(none), ())
  assert.eq(normalize-notes("Lieferung frei Haus."), (
    (text: "Lieferung frei Haus.", subject-code: none),
  ))
  assert.eq(
    normalize-notes((
      [Es gelten unsere AGB.],
      (
        text: "Geschäftsführer: Max Muster",
        subject-code: "REG",
      ),
    )),
    (
      (text: [Es gelten unsere AGB.], subject-code: none),
      (text: "Geschäftsführer: Max Muster", subject-code: "REG"),
    ),
  )
}

// --- 2. The XML states every note, with its line breaks ---
#let notes = (
  "Lieferung frei Haus.\nMontage nach Absprache.",
  (text: [Es gelten unsere *AGB*.], subject-code: "aai"),
  "",
)
#model-test(notes: notes, model => {
  assert.eq(model.invoice.notes, (
    (
      content: "Lieferung frei Haus.\nMontage nach Absprache.",
      subject-code: none,
    ),
    (content: "Es gelten unsere AGB.", subject-code: "AAI"),
  ))
  assert.eq(xml-elements(model, "ram:IncludedNote"), (
    "<ram:IncludedNote><ram:Content>Lieferung frei Haus.\nMontage nach Absprache.</ram:Content></ram:IncludedNote>",
    "<ram:IncludedNote><ram:Content>Es gelten unsere AGB.</ram:Content><ram:SubjectCode>AAI</ram:SubjectCode></ram:IncludedNote>",
  ))
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ())

  // BASIC WL states them as well
  let m = model
  m.profile = resolve-profile("basic-wl", "FR")
  assert.eq(xml-elements(m, "ram:IncludedNote").len(), 2)
  assert.eq(rules(m, level: "warning"), ())

  // MINIMUM has no notes: they are only printed
  m.profile = resolve-profile("minimum", "FR")
  assert.eq(xml-elements(m, "ram:IncludedNote"), ())
  assert.eq(rules(m, level: "warning"), ("IP-PROFILE-01",))
  assert.eq(diagnostic(m, "IP-PROFILE-01").field, "notes")

  // A subject code outside UNTDID 4451 (BR-CL-08)
  m = model
  m.invoice.notes.at(1).subject-code = "XYZ"
  assert.eq(rules(m), ("BR-CL-08",))
  assert(diagnostic(m, "BR-CL-08").message.contains("\"XYZ\""))
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 3. The notes are printed below the line items ---
// The layout of the line items gets them after the exemption notes, and
// still prints the tax statement.
#invoice(
  theme: () => (
    themes.blank()
      + (
        line-items: (ctx, view, body) => {
          assert.eq(
            view.exemption-notes.map(note => (note.kind, note.body)),
            (
              ("grounds", "Steuerfreie Leistung nach § 4 Nr. 21 UStG"),
              ("note", "Lieferung frei Haus.\nMontage nach Absprache."),
              ("note", [Es gelten unsere *AGB*.]),
            ),
          )
          []
        },
      )
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-fr,
  notes: notes.slice(0, 2),
)[
  #line-items[
    #item(
      [Kurs],
      price: 100,
      tax: tax.exempt(grounds: "Steuerfreie Leistung nach § 4 Nr. 21 UStG"),
    )
  ]
]

#invoice(
  theme: () => (
    themes.blank()
      + (
        line-items: (ctx, view, body) => {
          let printed = plain-text(
            (themes.blank().line-items)(ctx, view, body),
          )
          assert(printed.contains("Alle Artikel sind zzgl. 19"))
          assert(printed.contains("Lieferung frei Haus."))
          []
        },
      )
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-fr,
  notes: "Lieferung frei Haus.",
)[
  #line-items[#item([Beratung], price: 100, tax: tax.vat(19%))]
]
