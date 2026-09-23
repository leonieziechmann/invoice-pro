// The theme hook `zugferd-report` renders the e-invoice problems with
// `zugferd-errors: "report"`. `none` hides them, whatever the hook returns is
// shown as content, and a hook of the wrong type is named in the error.

#import "/src/lib.typ": *

// An e-invoice with problems: the invoice number (BR-02) and the payment terms
// (BR-CO-25) are missing.
#let test-invoice(theme) = invoice(
  theme: theme,
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "report",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: "80339 München",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Buyer SAS",
    address: "Rue 1",
    city: (name: "Paris", post-code: "75001"),
    country: country.fr,
    vat-id: "FR99123456789",
  ),
  date: datetime(year: 2026, month: 9, day: 1),
)[
  #line-items[#item([Consulting], price: 100)]
]

// A theme that records the document body, which starts with the report.
#let recording(..hook) = themes.blank.with(
  document: (ctx, body) => [#metadata(body)<body>#body],
  ..hook,
)

// --- 1. Themes whose hook is not a function are rejected with a clear error ---
#{
  let message = catch(() => test-invoice(recording(zugferd-report: "report")))
  assert(
    message.contains("variable `theme::zugferd-report`(\"report\") must be of"),
    message: "Unexpected error: " + repr(message),
  )

  // A theme dictionary that bypasses `base-theme`
  let custom-theme = () => (themes.blank)() + (zugferd-report: 42)
  assert.eq(
    catch(() => test-invoice(custom-theme)),
    "assertion failed: theme::zugferd-report must be `none` or a function `(ctx, result) => content`, got 42",
  )
}

// --- 2. Rendered cases, checked below ---
#test-invoice(recording(zugferd-report: none))
#test-invoice(recording(zugferd-report: (ctx, result) => none))
#test-invoice(recording(zugferd-report: (ctx, result) => (
  rules: result.diagnostics.map(d => d.rule),
)))
#test-invoice(recording(zugferd-report: (ctx, result) => (
  str(result.diagnostics.len()) + " problems"
)))
#test-invoice(recording())

#context {
  let bodies = query(<body>).map(it => repr(it.value))
  assert.eq(bodies.len(), 5)
  let (hidden, empty, dictionary, string, default) = bodies

  // `none` hides the report, like a hook that returns `none`
  assert(not hidden.contains("E-invoice"), message: hidden)
  assert(not hidden.contains("BR-02"), message: hidden)
  assert(not empty.contains("BR-02"), message: empty)

  // Other values are shown as they would be in markup
  assert(
    dictionary.contains("(rules: (\\\"BR-02\\\", \\\"BR-CO-25\\\"))"),
    message: dictionary,
  )
  assert(string.contains("2 problems"), message: string)

  // The default report
  assert(default.contains("[BR-02]"), message: default)
  assert(default.contains("[BR-CO-25]"), message: default)
}
