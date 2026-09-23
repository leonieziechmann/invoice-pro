// Multi-invoice documents for tytanic. A tytanic test cannot take `--input`, so
// a parameterised check of the theming prototype (one `typst compile` per preset,
// layout or region) renders every case as its own invoice in ONE document.
//
// Each case leaves a start marker as the first element of its body, and a final
// sentinel invoice (`close-cases()`) closes the last case: case k spans the
// pages from its marker to the page before the next marker (every `invoice()`
// sets its own page, so every case starts on a new page).
//
// Every invoice of a document is laid out and checked on its own: its page
// count (and with it the bottom margin the frame computes from the footer), page
// numbers, `pages: "first"`/`"rest"` areas, stationery, proof windows, identity
// check and draft report belong to that invoice alone, so a case behaves as it
// would in a document of its own. A draft case's report page lies inside its
// span. Visual refs still use one invoice per document.
//
// Multi-invoice tests are compile-only and set `/// [ppi: 12]`: tytanic still
// exports every page of a compile-only test, and these documents are long.
#import "/src/lib.typ": invoice, item, line-items, theme
#import "/tests/test-locale.typ": test-locale

/// The start marker of case `key`: the first element of the case's invoice body.
/// -> content
#let case-marker(key) = [#metadata(key) <case-start>]

/// One case: `invoice(..args)[body]` with a start marker. `key` identifies the
/// case in `spans()` and in messages.
/// -> content
#let case(key, ..args, body) = invoice(..args, [
  #case-marker(key)
  #body
])

/// The sentinel after the last case: a complete one-page invoice.
/// -> content
#let close-cases() = invoice(
  theme: theme.plain,
  locale: test-locale,
  validation: none,
  sender: (name: "S GmbH", address: "Weg 1", city: "20457 Hamburg"),
  recipient: (name: "R AG", address: "Weg 2", city: "80331 München"),
  invoice-nr: "0",
  [
    #metadata("__end__") <case-start>
    #line-items[#item([x], price: 1)]
  ],
)

/// The page span of every case, in document order: an array of
/// `(key: .., first: page, pages: n)`. Needs `context` and `close-cases()`.
/// -> array
#let spans() = {
  let starts = query(<case-start>)
  assert(
    starts.len() >= 2 and starts.last().value == "__end__",
    message: "harness: call close-cases() after the last case",
  )
  range(starts.len() - 1).map(i => {
    let a = starts.at(i).location().page()
    let b = starts.at(i + 1).location().page()
    (key: starts.at(i).value, first: a, pages: b - a)
  })
}

/// The span of one case by key. Needs `context`.
/// -> dictionary
#let span-of(key) = {
  let s = spans().find(s => s.key == key)
  assert(s != none, message: "harness: no case " + repr(key))
  s
}

/// The values of the metadata labelled `lbl` inside the pages of case `key`.
/// Needs `context`.
/// -> array
#let in-case(key, lbl) = {
  let s = span-of(key)
  query(lbl)
    .filter(m => {
      let p = m.location().page()
      p >= s.first and p < s.first + s.pages
    })
    .map(m => m.value)
}

/// The draft issues (`<ip-issue>` metadata) of case `key`, deduplicated, in
/// document order. Needs `context`.
/// -> array
#let issues-of(key) = {
  let out = ()
  for x in in-case(key, <ip-issue>) {
    if x not in out { out.push(x) }
  }
  out
}
