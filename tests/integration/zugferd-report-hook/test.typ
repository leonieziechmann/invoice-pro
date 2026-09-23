// The theme hook `zugferd-report` renders the e-invoice problems with
// `zugferd-errors: "report"`. Whatever the hook returns is shown as content,
// and a hook of the wrong type is named in the error. A theme that shows no
// report (`none`, or a hook returning nothing) must not hide errors: they stop
// the compilation, warnings are left out.

#import "/src/lib.typ": *

// An e-invoice with errors: the invoice number (BR-02) and the payment terms
// (BR-CO-25) are missing. With `warnings-only`, they are given and the only
// problem is a warning: the IBAN has wrong check digits (BR-DE-19).
#let test-invoice(theme, warnings-only: false) = invoice(
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
  ..if warnings-only { (invoice-nr: "RE-2026-001") },
)[
  #line-items[#item([Consulting], price: 100)]
  #if warnings-only {
    payment-goal(days: 14)
    bank-details(iban: "DE00370400440532013000")
  }
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

// --- 2. Without a report, errors stop the compilation ---
#{
  let lead = "assertion failed: The theme shows no e-invoice report (theme::zugferd-report is `none` or returns nothing), so the errors below stop the compilation even with `zugferd-errors: \"report\"`.\nThe e-invoice (ZUGFeRD / Factur-X, profile EN 16931 (COMFORT)) is not valid: 2 errors."
  for hook in (none, (ctx, result) => none, (ctx, result) => []) {
    let message = catch(() => test-invoice(recording(zugferd-report: hook)))
    assert(
      type(message) == str and message.starts-with(lead),
      message: "Unexpected error: " + repr(message),
    )
    assert(message.contains("[BR-02]"), message: message)
    assert(message.contains("[BR-CO-25]"), message: message)
  }
}

// --- 3. Rendered cases, checked below ---
#test-invoice(recording(zugferd-report: none), warnings-only: true)
#test-invoice(
  recording(zugferd-report: (ctx, result) => none),
  warnings-only: true,
)
#test-invoice(recording(zugferd-report: (ctx, result) => (
  rules: result.diagnostics.map(d => d.rule),
)))
#test-invoice(recording(zugferd-report: (ctx, result) => (
  str(result.diagnostics.len()) + " problems"
)))
#test-invoice(recording())
#test-invoice(recording(), warnings-only: true)

#context {
  let bodies = query(<body>).map(it => repr(it.value))
  assert.eq(bodies.len(), 6)
  let (hidden, empty, dictionary, string, default, warnings) = bodies

  // Warnings alone do not stop the compilation: `none` hides them, like a
  // hook that returns `none`
  assert(not hidden.contains("E-invoice"), message: hidden)
  assert(not hidden.contains("BR-DE-19"), message: hidden)
  assert(not empty.contains("BR-DE-19"), message: empty)

  // Other values are shown as they would be in markup
  assert(
    dictionary.contains("(rules: (\\\"BR-02\\\", \\\"BR-CO-25\\\"))"),
    message: dictionary,
  )
  assert(string.contains("2 problems"), message: string)

  // The default report
  assert(default.contains("[BR-02]"), message: default)
  assert(default.contains("[BR-CO-25]"), message: default)
  assert(warnings.contains("[BR-DE-19]"), message: warnings)
  assert(not warnings.contains("[BR-02]"), message: warnings)
}
