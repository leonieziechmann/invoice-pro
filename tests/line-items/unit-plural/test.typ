// Units follow the quantity of their own item or bundle.
//
// Bug: the unit was resolved with the parent context's quantity, so it always
// stayed singular ("2 day", "2 Tag"). Checked for en and de with the
// quantities 1, 2 and 2.5 on unit presets, a (singular:, plural:) dictionary,
// a plain string (stays as given), the default unit and a bundle unit.
//
// `unit-singular` is the quantity-independent form used to detect a shared
// unit and to name it in the "unit for all items" note.

#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom

#let quantities = (1, 2, 2.5)

#let check-units(loc, licence: none, plain: none, expected: (:)) = {
  let preset(code, name) = (code: code, name: name, display: name)
  let bare(name) = (display: name, name: name)

  // Expected units in document order, per quantity index.
  let expected-at(i) = (
    preset("DAY", expected.day.at(i)),
    bare(expected.licence.at(i)),
    expected.plain.at(i),
    preset("H87", expected.piece.at(i)),
    preset("SET", expected.sets.at(i)),
  )
  let expected-units = range(quantities.len()).map(expected-at).flatten()
  let expected-singular = range(quantities.len())
    .map(_ => expected-at(0))
    .flatten()

  // Two invoices in one document: bare fixtures, so validation is off.
  invoice(
    theme: theme.plain,
    locale: loc,
    sender: (name: "Test Sender", address: "Street 1", city: "City"),
    recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
    validation: none,
  )[
    #data-test(test: (ctx, data) => {
      let items = loom.query.find-signal(data, "line-items").item-data.items

      assert.eq(
        items.len(),
        expected-units.len(),
        message: "Item count: expected "
          + str(expected-units.len())
          + ", got "
          + str(items.len()),
      )
      for (item, unit, singular) in items.zip(
        expected-units,
        expected-singular,
      ) {
        assert.eq(
          item.unit,
          unit,
          message: repr(item.name)
            + " unit: expected "
            + repr(unit)
            + ", got "
            + repr(item.unit),
        )
        assert.eq(
          item.unit-singular,
          singular,
          message: repr(item.name)
            + " unit-singular: expected "
            + repr(singular)
            + ", got "
            + repr(item.unit-singular),
        )
      }
    })[
      #line-items[
        #for q in quantities [
          #item("Day " + str(q), price: 1, quantity: q, unit: unit.day)
          #item("Licence " + str(q), price: 1, quantity: q, unit: licence)
          #item("Plain " + str(q), price: 1, quantity: q, unit: plain)
          #item("Default " + str(q), price: 1, quantity: q)
          #bundle("Bundle " + str(q), quantity: q, unit: unit.sets)[
            #item("Part", price: 1)
          ]
        ]
      ]
    ]
  ]
}

#check-units(
  locale.en-de,
  licence: (singular: "licence", plural: "licences"),
  plain: "hrs",
  expected: (
    day: ("day", "days", "days"),
    licence: ("licence", "licences", "licences"),
    plain: ("hrs", "hrs", "hrs"),
    piece: ("piece", "pieces", "pieces"),
    sets: ("set", "sets", "sets"),
  ),
)

#check-units(
  locale.de-de,
  licence: (singular: "Lizenz", plural: "Lizenzen"),
  plain: "Std.",
  expected: (
    day: ("Tag", "Tage", "Tage"),
    licence: ("Lizenz", "Lizenzen", "Lizenzen"),
    plain: ("Std.", "Std.", "Std."),
    // German "Stück" has no plural form, so it stays as is.
    piece: ("Stück", "Stück", "Stück"),
    sets: ("Satz", "Sätze", "Sätze"),
  ),
)
