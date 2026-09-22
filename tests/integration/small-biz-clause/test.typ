// Small-business legal clause in the global info block
//
// Bug: with `tax-exempt-small-biz: true`, a locale whose language matches its
// region (e.g. `de-de`, or `test-locale` with `base`/`base`) printed no legal
// notice at all when the region's `small-enterprise-special-scheme` had no
// `grounds`. It must fall back to the translated `legal.vat-exemption` text.

#import "/src/lib.typ": *
#import "/src/themes/components/line-items/global-info.typ": render-global-info
#import "/tests/test-locale.typ": test-locale

/// Flattens rendered content into its plain text.
#let plain(it) = {
  if type(it) == str { return it }
  if type(it) != content { return "" }
  if it.has("text") { return it.text }
  if it.has("children") { return it.children.map(plain).sum(default: "") }
  if it.has("body") { return plain(it.body) }
  if it.has("child") { return plain(it.child) }
  if it == [ ] { " " } else { "" }
}

/// Invoice whose line-items hook renders the global info block and asserts
/// that it contains `expected` (a function of the evaluated locale).
#let clause-invoice(scenario, locale: test-locale, expected, body) = invoice(
  theme: themes.blank.with(
    line-items: (ctx, data, body) => {
      let clause = expected(ctx.locale)
      let info = plain(render-global-info(ctx, data))
      assert(
        info.contains(clause),
        message: scenario
          + ": expected small-biz clause "
          + repr(clause)
          + ", got "
          + repr(info),
      )
      body
    },
  ),
  locale: locale,
  tax-exempt-small-biz: true,
  sender: (
    name: "Kleinunternehmer",
    address: "Str 1",
    city: "Berlin",
    country: country.de,
  ),
  recipient: (
    name: "Client",
    address: "Str 2",
    city: "Berlin",
    country: country.de,
  ),
  body,
)

// 1. test-locale (lang == region == "base", scheme without grounds):
//    falls back to the base language clause
#clause-invoice(
  "test-locale",
  _ => "No VAT is charged due to small business exemption.",
)[
  #line-items[
    #item([Small Biz Item], price: 100.00)
  ]
]

// 2. de-de with a grounds-less scheme override: falls back to the German clause
#clause-invoice(
  "de-de without grounds",
  locale: locale.de-de.with(
    locale.custom.tax(small-enterprise-special-scheme: tax.outside-scope()),
  ),
  l => l.strings.legal.vat-exemption,
)[
  #line-items[
    #item([Kleinunternehmer-Leistung], price: 100.00)
  ]
]

// 3. Shipped de-de (lang == region, with grounds): prints the regional grounds
#clause-invoice(
  "de-de",
  locale: locale.de-de,
  l => l.tax.small-enterprise-special-scheme.grounds,
)[
  #line-items[
    #item([Kleinunternehmer-Leistung], price: 100.00)
  ]
]

// 4. en-de (lang != region, with grounds): translated clause plus grounds
#clause-invoice(
  "en-de",
  locale: locale.en-de,
  l => (
    l.strings.legal.vat-exemption
      + " ("
      + l.tax.small-enterprise-special-scheme.grounds
      + ")"
  ),
)[
  #line-items[
    #item([Small Biz Item], price: 100.00)
  ]
]
