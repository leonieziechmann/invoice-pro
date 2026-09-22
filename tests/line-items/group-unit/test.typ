// A group's `unit` cascades to its items and bundles, and each of them
// resolves it with its own quantity ("1 hour", "2 hours").
//
// Bug: items and bundles always resolved their own `unit: auto` to the default
// piece, overwriting the unit the group had put into the context.
//
// Uses `locale.en-de` instead of `test-locale`: the base language has no
// plural forms, and the plural shows that the unit is resolved per item.

#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom

#show: invoice.with(
  theme: themes.blank,
  locale: locale.en-de,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
)

#let hour(name) = (code: "HUR", name: name, display: name)
#let day(name) = (code: "DAY", name: name, display: name)
#let piece(name) = (code: "H87", name: name, display: name)
#let licence(name) = (display: name, name: name)

// Item name: (unit, unit-singular)
#let expected = (
  "Group 1": (hour("hour"), hour("hour")),
  "Group 2": (hour("hours"), hour("hour")),
  "Own unit": (day("days"), day("day")),
  "Own none": (none, none),
  "Nested inherit": (hour("hours"), hour("hour")),
  "Nested override 1": (licence("licence"), licence("licence")),
  "Nested override 2.5": (licence("licences"), licence("licence")),
  "Bundle": (hour("hours"), hour("hour")),
  "Apply": (day("days"), day("day")),
  "Outside": (piece("pieces"), piece("piece")),
)

#data-test(test: (ctx, data) => {
  let items = loom.query.find-signal(data, "line-items").item-data.items

  assert.eq(
    items.map(i => i.name),
    expected.keys(),
    message: "Items: expected "
      + repr(expected.keys())
      + ", got "
      + repr(items.map(i => i.name)),
  )
  for item in items {
    let (unit, singular) = expected.at(item.name)
    assert.eq(
      item.unit,
      unit,
      message: item.name
        + " unit: expected "
        + repr(unit)
        + ", got "
        + repr(item.unit),
    )
    assert.eq(
      item.unit-singular,
      singular,
      message: item.name
        + " unit-singular: expected "
        + repr(singular)
        + ", got "
        + repr(item.unit-singular),
    )
  }
})[
  #line-items[
    #group([Hours], unit: unit.hour)[
      #item("Group 1", price: 1, quantity: 1)
      #item("Group 2", price: 1, quantity: 2)
      #item("Own unit", price: 1, quantity: 2, unit: unit.day)
      #item("Own none", price: 1, quantity: 2, unit: none)

      #group([Inherits hours])[
        #item("Nested inherit", price: 1, quantity: 2)
      ]
      #group([Licences], unit: (singular: "licence", plural: "licences"))[
        #item("Nested override 1", price: 1, quantity: 1)
        #item("Nested override 2.5", price: 1, quantity: 2.5)
      ]

      #bundle("Bundle", quantity: 2)[
        #item("Part", price: 1)
      ]
    ]

    #apply(unit: unit.day)[
      #item("Apply", price: 1, quantity: 2)
    ]

    #item("Outside", price: 1, quantity: 2)
  ]
]
