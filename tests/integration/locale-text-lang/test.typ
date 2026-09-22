// Regression test: the document language follows the locale.
//
// Bug: every invoice was set with `text.lang: "de"`, whatever the locale,
// because the locale factory only stored the language code under
// `strings.meta.lang` and the root fell back to a hard-coded "de". English and
// French invoices got German hyphenation, a German PDF language tag, and
// letter-pro's footer printed "Seite 1 von 2".

#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

// letter-pro renders the page label as "Page x of y", or "Seite x von y" when
// `text.lang` is "de". Tag each rendered label so it can be queried per page.
#let tag-page-label(it) = [#it#metadata(it.text) <locale-text-lang-footer>]
#show regex("(Page|Seite) \d+ (of|von) \d+"): tag-page-label

#let probe(scenario) = context [#metadata((
  scenario: scenario,
  lang: text.lang,
  region: text.region,
)) <locale-text-lang-probe>]

// Two pages per invoice, so letter-pro prints a page label on each of them.
#let scenario(name, locale) = invoice(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale,
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
  let expect-labels(scenario, pattern) = {
    let found = page-labels(scenario)
    assert.eq(
      found.len(),
      2,
      message: scenario + ": expected 2 page labels, got " + repr(found),
    )
    for label in found {
      assert(
        label.match(regex("^" + pattern + "$")) != none,
        message: scenario
          + ": page label: expected "
          + repr(pattern)
          + ", got "
          + repr(label),
      )
    }
  }

  let english = "Page \d+ of \d+"
  expect-labels("en-de", english)
  // letter-pro only localizes the label for German.
  expect-labels("fr-fr", english)
  expect-labels("de-de", "Seite \d+ von \d+")
  expect-labels("base", english)
}
