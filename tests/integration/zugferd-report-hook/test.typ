// The `zugferd-report` part of the theme renders the e-invoice problems with
// `zugferd-errors: "report"`. Whatever the part returns is shown as content,
// and a renderer of the wrong type is named in the error. A theme that shows
// no report (`none`, or a renderer returning nothing) must not hide errors:
// they stop the compilation, warnings are left out.

#import "/src/lib.typ": *

// An e-invoice with errors: the invoice number (BR-02) and the payment terms
// (BR-CO-25) are missing. With `warnings-only`, they are given and the only
// problem is a warning: the sender has a key the e-invoice does not read
// (IP-KEY-01). The checks of the invoice data are off: they would withhold
// the XML of the invoice without its number instead of validating it.
#let test-invoice(theme, warnings-only: false) = invoice(
  theme: theme,
  locale: locale.de-de,
  validation: none,
  zugferd: "en16931",
  zugferd-errors: "report",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: "80339 München",
    vat-id: "DE123456789",
    ..if warnings-only { (fax-nr: "+49 89 1234568") },
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
    payment-terms(days: 14)
    bank-details(iban: "DE89370400440532013000")
  }
]

// A theme whose report part (`hook`, the default one for `auto`) records what
// it shows, under `id`. A report that returns nothing is not recorded: the
// record would be shown in its place.
#let recording(id, hook: auto) = theme.plain.with(theme.custom.part(
  "zugferd-report",
  if hook == none { none } else {
    (ctx, result) => {
      let out = if hook == auto {
        theme.parts.zugferd-report(ctx, result)
      } else {
        hook(ctx, result)
      }
      if out in (none, "", []) { out } else {
        [#metadata((id: id, shown: repr(out)))<shown>#out]
      }
    }
  },
))

// --- 1. A report part that is not a function is rejected with a clear error ---
#{
  let message = catch(() => test-invoice(theme.plain.with(theme.custom.part(
    "zugferd-report",
    "report",
  ))))
  assert(
    type(message) == str
      and message.contains("theme::parts::zugferd-report")
      and message.contains("must be a function"),
    message: "Unexpected error: " + repr(message),
  )
}

// --- 2. Without a report, errors stop the compilation ---
#{
  let lead = "assertion failed: The theme shows no e-invoice report (the part `zugferd-report` is `none` or returns nothing), so the errors below stop the compilation even with `zugferd-errors: \"report\"`.\nThe e-invoice (ZUGFeRD / Factur-X, profile EN 16931 (COMFORT)) is not valid: 2 errors."
  for hook in (none, (ctx, result) => none, (ctx, result) => []) {
    let message = catch(() => test-invoice(recording("stop", hook: hook)))
    assert(
      type(message) == str and message.starts-with(lead),
      message: "Unexpected error: " + repr(message),
    )
    assert(message.contains("[BR-02]"), message: message)
    assert(message.contains("[BR-CO-25]"), message: message)
  }
}

// --- 3. Rendered cases, checked below ---
#test-invoice(recording("hidden", hook: none), warnings-only: true)
#test-invoice(
  recording("empty", hook: (ctx, result) => none),
  warnings-only: true,
)
#test-invoice(recording("dictionary", hook: (ctx, result) => (
  rules: result.diagnostics.map(d => d.rule),
)))
#test-invoice(recording("string", hook: (ctx, result) => (
  str(result.diagnostics.len()) + " problems"
)))
#test-invoice(recording("default"))
#test-invoice(recording("warnings"), warnings-only: true)

#context {
  let shown = (:)
  for it in query(<shown>) { shown.insert(it.value.id, it.value.shown) }
  assert.eq(
    shown.keys(),
    ("dictionary", "string", "default", "warnings"),
    message: repr(shown.keys()),
  )

  // Warnings alone do not stop the compilation: `none` hides them, like a
  // part that returns `none` (neither is shown)

  // Other values are shown as they would be in markup
  assert(
    shown.dictionary.contains("(rules: (\"BR-02\", \"BR-CO-25\"))"),
    message: shown.dictionary,
  )
  assert(shown.string.contains("2 problems"), message: shown.string)

  // The default report
  assert(shown.default.contains("[BR-02]"), message: shown.default)
  assert(shown.default.contains("[BR-CO-25]"), message: shown.default)
  assert(shown.warnings.contains("[IP-KEY-01]"), message: shown.warnings)
  assert(not shown.warnings.contains("[BR-02]"), message: shown.warnings)
}
