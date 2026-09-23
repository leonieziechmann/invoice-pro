// The exemption notes below the line items, as `line-items` prepares them for
// the theme (`exemption-notes` in its view): which notes are printed, in
// which order and with which marker. The theme only prints them.

#import "/src/lib.typ": *
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region
#import "/src/logic/exemption-notes.typ": (
  assign-markers, group-markers, item-marker,
)
#import "/src/themes/components/line-items/global-info.typ": render-global-info
#import "/tests/integration/payment-reference/harness.typ": plain
#import "/tests/test-locale.typ": test-locale

#let g14 = "Steuerfrei nach § 4 Nr. 14 UStG"
#let g21 = "Steuerfrei nach § 4 Nr. 21 UStG"

// The lines of the global information below the line items.
#let printed-lines(ctx, data) = (
  plain(render-global-info(ctx, data)).split("\n").map(line => line.trim())
)

// --- 1. Markers ---
#{
  let taxes = (
    "0.19-S": (rate: decimal("0.19"), category: "S", grounds-list: ()),
    "0-E": (rate: decimal("0"), category: "E", grounds-list: (g14, [#g21])),
    "0-AE": (rate: decimal("0"), category: "AE", grounds-list: (g21,)),
  )
  let markers = assign-markers(taxes)
  // A ground given as string and as content has one marker.
  assert.eq(markers.grounds, ((g14): "*", (g21): "**"))
  assert.eq(markers.itemized, ("0-E": true))
  assert.eq(group-markers(taxes.at("0-E"), markers), ("*", "**"))
  assert.eq(group-markers(taxes.at("0.19-S"), markers), ())
  // Items are marked only in a category with several grounds.
  assert.eq(item-marker(tax.exempt(grounds: g21), markers), "**")
  assert.eq(item-marker(tax.exempt(), markers), none)
  assert.eq(item-marker(tax.reverse-charge(grounds: g21), markers), none)

  // After four markers, the grounds are numbered.
  let many = (:)
  for i in range(6) { many.insert("0-E" + str(i), (grounds-list: (str(i),))) }
  assert.eq(
    assign-markers(many).grounds.values(),
    ("*", "**", "***", "****", "*5", "*6"),
  )
}

// --- 2. Notes of an invoice ---

// Runs `test` with the notes and the lines of the printed global information.
#let check(test, ..args, body) = invoice(
  theme: themes.blank.with(line-items: (ctx, data, body) => {
    test(data.exemption-notes, printed-lines(ctx, data))
    body
  }),
  locale: test-locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  ..args,
  body,
)

#let note(body, marker: none, kind: "grounds") = (
  kind: kind,
  marker: marker,
  body: body,
)

// Two grounds in one category: the tax column marks the items, so the notes
// show the markers.
#check((notes, lines) => {
  assert.eq(notes, (note(g14, marker: "*"), note(g21, marker: "**")))
  assert.eq(lines.slice(-2), ("* " + g14, "** " + g21))
})[
  #line-items[
    #item([Treatment], price: 90, tax: tax.exempt(grounds: g14))
    #item([Seminar], price: 300, tax: tax.exempt(grounds: g21))
    #item([Book], price: 20, tax: tax.vat(7%))
  ]
]

// Without the tax column, nothing shows the markers of the 0% category.
#check((notes, lines) => {
  assert.eq(notes, (note(g14), note(g21)))
  assert.eq(lines.slice(-2), (g14, g21))
})[
  #line-items(show-column: (tax-rate: false))[
    #item([Treatment], price: 90, tax: tax.exempt(grounds: g14))
    #item([Seminar], price: 300, tax: tax.exempt(grounds: g21))
    #item([Book], price: 20, tax: tax.vat(7%))
  ]
]

// One ground in a 0% category: its VAT line is not printed, so neither is
// its marker. The ground replaces the standard tax statement.
#let reverse-charge = tax.reverse-charge(grounds: "Reverse charge")
#check((notes, lines) => {
  assert.eq(notes, (note("Reverse charge"),))
  assert.eq(lines.last(), "Reverse charge")
  assert(lines.all(line => not line.contains("%")), message: repr(lines))
})[
  #line-items[
    #item([Consulting], price: 1000, tax: reverse-charge)
  ]
]

// A ground of a category with VAT points to its VAT line in the totals.
#let reduced = tax.new(rate: 7%, category: "S", grounds: "Reduced rate")
#check((notes, lines) => {
  assert.eq(notes, (note("Reduced rate", marker: "*"),))
  assert.eq(lines.last(), "* Reduced rate")
})[
  #line-items[
    #item([Book], price: 20, tax: reduced)
    #item([Consulting], price: 100, tax: tax.vat(19%))
  ]
]
#check((notes, lines) => {
  assert.eq(notes, (note("Reduced rate"),))
})[
  #line-items(show-total: false)[
    #item([Book], price: 20, tax: reduced)
    #item([Consulting], price: 100, tax: tax.vat(19%))
  ]
]

// The same ground, as string and as content, is printed once.
#check((notes, lines) => {
  assert.eq(notes, (note(g14),))
})[
  #line-items[
    #item([A], price: 90, tax: tax.exempt(grounds: g14))
    #item([B], price: 50, tax: tax.exempt(grounds: [#g14]))
    #item([C], price: 30, tax: tax.reverse-charge(grounds: g14))
  ]
]

// Without grounds, there are no notes and the standard tax statement stays.
#check((notes, lines) => {
  assert.eq(notes, ())
  assert(lines.any(line => line.contains("19%")), message: repr(lines))
})[
  #line-items[#item([A], price: 90, tax: tax.vat(19%))]
]

// --- 3. The small business clause ---
#let small-biz(scheme-locale, test, body) = check(
  test,
  locale: scheme-locale,
  tax-exempt-small-biz: true,
  body,
)

// The legal clause (in the language) and the legal grounds (of the region)
// of the small business scheme of a locale.
#let scheme(scheme-locale) = {
  let evaluated = scheme-locale(base-language, base-region)
  (
    clause: evaluated.strings.legal.vat-exemption,
    grounds: evaluated
      .tax
      .small-enterprise-special-scheme
      .at("grounds", default: none),
  )
}

// The legal grounds of the region, in its language, printed once although an
// item states them as well.
#let de = scheme(locale.de-de)
#small-biz(locale.de-de, (notes, lines) => {
  assert.ne(de.grounds, none)
  assert.eq(notes, (note(de.grounds, kind: "small-business"),))
})[
  #line-items[
    #item([A], price: 90)
    #item([B], price: 50, tax: tax.exempt(grounds: de.grounds))
  ]
]

// In another language: the translated clause with the legal grounds.
#let en = scheme(locale.en-de)
#small-biz(locale.en-de, (notes, lines) => {
  assert.eq(notes.map(n => (n.kind, n.marker)), (("small-business", none),))
  assert.eq(
    plain(notes.first().body),
    plain(en.clause) + " (" + plain(en.grounds) + ")",
  )
})[
  #line-items[#item([A], price: 90)]
]

// Without legal grounds: the clause on its own.
#let base = scheme(test-locale)
#small-biz(test-locale, (notes, lines) => {
  assert.eq(base.grounds, none)
  assert.eq(notes, (note(base.clause, kind: "small-business"),))
})[
  #line-items[#item([A], price: 90)]
]

// A scheme with VAT links the clause to its VAT line.
#small-biz(
  locale.de-de.with(locale.custom.tax(
    small-enterprise-special-scheme: tax.new(
      rate: 5%,
      category: "S",
      grounds: "Special scheme",
    ),
  )),
  (notes, lines) => {
    assert.eq(notes, (
      note("Special scheme", marker: "*", kind: "small-business"),
    ))
  },
)[
  #line-items[#item([A], price: 90)]
]

// --- 4. The layout prints the prepared notes ---
#{
  let ctx = (
    locale: (
      strings: (
        summary: (excluding: "excl.", including: "incl.", vat-tax: "VAT"),
        global-info: (tax-statement: (..) => [statement]),
      ),
    ),
  )
  let data = (
    layout-information: (
      show-tax-rates: false,
      multiple-tax-rates: false,
      show-units: true,
      multiple-units: false,
      show-quantity: true,
      multiple-quantities: false,
      show-dates: true,
      has-dates: false,
      multiple-dates: false,
      show-global-information: true,
    ),
    tax-mode: "exclusive",
    items: ((tax: (rate: [0%])),),
    tax-exempt-small-biz: false,
    exemption-notes: (note([First], marker: "*"), note([Second])),
  )
  // The notes replace the standard tax statement.
  assert.eq(printed-lines(ctx, data), ("* First", "Second"))
  assert.eq(printed-lines(ctx, data + (exemption-notes: ())), ("statement",))
  // `show-information: false` hides the information about the items, but
  // not the notes, which the law requires and the e-invoice states.
  let hidden = data
  hidden.layout-information.show-global-information = false
  hidden.exemption-notes.push(note([Invoice note], kind: "note"))
  assert.eq(printed-lines(ctx, hidden), ("* First", "Second", "Invoice note"))
  hidden.exemption-notes = ()
  assert.eq(render-global-info(ctx, hidden), none)
}

// --- 4. `line-items(show-information: false)` keeps the exemption notes
// (§ 14 Abs. 4 Satz 1 Nr. 8 and § 14a Abs. 5 UStG) and the notes of the
// invoice, which the e-invoice states (BT-120, BT-22) ---
#check(
  notes: "Lieferung frei Haus.",
  (notes, lines) => {
    assert.eq(lines, ("Reverse charge", "Lieferung frei Haus."))
  },
)[
  #line-items(show-information: false)[
    #item([Beratung], price: 100, tax: tax.vat(19%))
    #item([Bauleistung], price: 200, tax: tax.reverse-charge())
  ]
]
#check((notes, lines) => assert.eq(lines, ("",)))[
  #line-items(show-information: false)[
    #item([Beratung], price: 100, tax: tax.vat(19%))
  ]
]
