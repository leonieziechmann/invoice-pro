// Regression test: the document language follows the locale.
//
// Bug: every invoice was set with `text.lang: "de"`, whatever the locale,
// because the locale factory only stored the language code under
// `strings.meta.lang` and the root fell back to a hard-coded "de". English and
// French invoices got German hyphenation, a German PDF language tag, and the
// page footer printed "Seite 1 von 2".

#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

/// Flattens rendered content into its plain text.
#let plain(it) = {
  if it == none { return "" }
  if type(it) == str { return it }
  if type(it) != content { return str(it) }
  if it.has("text") { return it.text }
  if it.has("children") { return it.children.map(plain).sum(default: "") }
  if it.has("child") { return plain(it.child) }
  if it.has("body") { return plain(it.body) }
  if it == [ ] { " " } else { "" }
}

// The frame prints the page label with the `page-number` part, from the
// locale's `strings.document.page`. Tag each rendered label, with the language
// it is set in, so it can be queried per page.
#let tag-page-label(ctx, view, inner) = {
  let label = inner(ctx, view)
  if label == none { return none }
  [#label#context [#metadata((
      text: plain(label),
      lang: text.lang,
    ))<locale-text-lang-footer>]]
}

#let probe(scenario) = context [#metadata((
  scenario: scenario,
  lang: text.lang,
  region: text.region,
)) <locale-text-lang-probe>]

// Two pages per invoice, so the frame prints a page label on each of them.
// Several invoices in one document: bare fixtures, so validation is off.
#let scenario(name, locale) = invoice(
  theme: theme.classic.with(
    theme.custom.fonts(body: "libertinus serif"),
    theme.custom.wrap("page-number", tag-page-label),
  ),
  locale: locale,
  validation: none,
  sender: (name: "Test Sender", address: "Street 1", city: "12345 City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "54321 City"),
  invoice-nr: "LANG-" + name,
  date: datetime(year: 2026, month: 1, day: 15),
)[
  #probe(name)
  #line-items[
    #item([Consulting], price: 100.00)
  ]
  #pagebreak()
  #probe(name)
]

// Invoices do not break the page on their own; keep each one on its own pages.
#scenario("en-de", locale.en-de)
#pagebreak()
#scenario("fr-fr", locale.fr-fr)
#pagebreak()
#scenario("de-de", locale.de-de)
#pagebreak()
#scenario("base", test-locale)

#context {
  let probes = query(<locale-text-lang-probe>)
  let labels = query(<locale-text-lang-footer>)

  let probe-values(scenario) = (
    probes.map(m => m.value).filter(v => v.scenario == scenario)
  )
  let expect-lang(scenario, lang, region) = {
    let values = probe-values(scenario)
    assert.eq(
      values.len(),
      2,
      message: scenario + ": expected 2 probes, got " + repr(values.len()),
    )
    for v in values {
      assert.eq(
        v.lang,
        lang,
        message: scenario
          + ": text.lang: expected "
          + repr(lang)
          + ", got "
          + repr(v.lang),
      )
      assert.eq(
        v.region,
        region,
        message: scenario
          + ": text.region: expected "
          + repr(region)
          + ", got "
          + repr(v.region),
      )
    }
  }

  expect-lang("en-de", "en", "DE")
  expect-lang("fr-fr", "fr", "FR")
  expect-lang("de-de", "de", "DE")
  // The base (fallback) language is English; its region is not a country.
  expect-lang("base", "en", none)

  // Page labels rendered on the pages of a scenario's invoice.
  let page-labels(scenario) = {
    let pages = probes
      .filter(m => m.value.scenario == scenario)
      .map(m => m.location().page())
    labels.filter(m => m.location().page() in pages).map(m => m.value)
  }
  // Each label is the locale's `strings.document.page`, set in its language.
  let expect-labels(scenario, pattern, lang) = {
    let found = page-labels(scenario)
    assert.eq(
      found.len(),
      2,
      message: scenario + ": expected 2 page labels, got " + repr(found),
    )
    for label in found {
      assert(
        label.text.match(regex("^" + pattern + "$")) != none,
        message: scenario
          + ": page label: expected "
          + repr(pattern)
          + ", got "
          + repr(label.text),
      )
      assert.eq(
        label.lang,
        lang,
        message: scenario
          + ": page label text.lang: expected "
          + repr(lang)
          + ", got "
          + repr(label.lang),
      )
    }
  }

  let english = "Page \d+ of \d+"
  expect-labels("en-de", english, "en")
  expect-labels("fr-fr", "Page \d+ sur \d+", "fr")
  expect-labels("de-de", "Seite \d+ von \d+", "de")
  expect-labels("base", english, "en")
}
