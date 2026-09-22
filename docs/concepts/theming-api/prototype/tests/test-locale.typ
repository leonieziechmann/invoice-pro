#import "/src/locale/factory.typ": build-locale
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region
#import "/src/data/tax.typ"

/// A stable locale for tests to ensure they don't break when standard locales change.
#let test-lang = base-language

/// A stable region for tests.
#let test-region(lang) = {
  let res = base-region

  // Provide a stable tax inference for tests
  res.normalize.infer-tax = rate => {
    tax.vat(rate)
  }

  // Ensure we have a stable currency
  res.currency = (
    code: "EUR",
    symbol: "€",
    decimals: 2,
    decimals-fine: 4,
  )

  res
}

#let test-locale = build-locale(test-lang, test-region)
