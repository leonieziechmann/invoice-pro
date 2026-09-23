// Names and descriptions of bundle lines.
//
// Bugs:
// - The line of a bundle with mixed VAT rates was named with the rate
//   rounded to an integer: "(6% S)" for 5.5%, "(2% S)" for 2.1%, printed and
//   in the XML (BT-153).
// - The automatic description joined the item names with a hard-coded
//   English "and", also on German or French invoices and in the XML (BT-154).
//
// Expected: the rate is formatted like everywhere else ("5,5%"), and the
// conjunction comes from the language of the locale.

#import "/src/lib.typ": *
#import "/src/utils/coercion.typ": to-string
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#let check(test, locale: test-locale, ..args, body) = invoice(
  theme: themes.blank,
  locale: locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  ..args,
  data-test(
    test: (ctx, data) => test(loom.query.find-signal(data, "line-items")),
    body,
  ),
)

// The texts of a field of all lines.
#let texts(li, field) = li.item-data.items.map(i => to-string(i.at(field)))

// --- 1. Non-integer rates in the names of the bracket lines ---
#check(li => {
  assert.eq(
    texts(li, "name"),
    ("Gift box (5,5% S)", "Gift box (20% S)", "Gift box (2,1% S)"),
  )
})[
  #line-items[
    #bundle([Gift box])[
      #item([Chocolate], price: 20, tax: tax.vat(5.5%))
      #item([Glass], price: 10, tax: tax.vat(20%))
      #item([Magazine], price: 7, tax: tax.vat(2.1%))
    ]
  ]
]

// --- 2. The conjunction of the automatic description ---
#check(
  locale: locale.de-de,
  li => assert.eq(texts(li, "description"), ("A, B und C",)),
)[
  #line-items[
    #bundle([Paket])[
      #item([A], price: 10)
      #item([B], price: 10)
      #item([C], price: 10)
    ]
  ]
]
#check(
  locale: locale.fr-fr,
  li => assert.eq(texts(li, "description"), ("A et B",)),
)[
  #line-items[
    #bundle([Coffret])[
      #item([A], price: 10)
      #item([B], price: 10)
    ]
  ]
]
#check(li => assert.eq(texts(li, "description"), ("A and B",)))[
  #line-items(tax: tax.vat(19%))[
    #bundle([Package])[
      #item([A], price: 10)
      #item([B], price: 10)
    ]
  ]
]
