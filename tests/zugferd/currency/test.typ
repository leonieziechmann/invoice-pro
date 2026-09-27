// The invoice currency (BT-5) and the printed amounts come from the same
// source, the currency of the locale's region: setting it changes the code
// and the printed symbol together. An invoice that prints another currency
// than the XML states is an error, and so are currencies the EN 16931
// validation does not know.

#import "/src/lib.typ": *
#import "/src/locale/factory.typ": build-locale
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region
#import "/src/utils/text.typ": plain-text
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, buyer-fr, diagnostic, model-test, rules,
)

#let evaluate(locale) = locale(base-language, base-region)
#let printed(locale, value) = plain-text((locale.format.currency)(value))
#let printed-fine(locale, value) = plain-text(
  (locale.format.currency-fine)(value),
)

// --- 1. The built-in locales print as before ---
#{
  let de = evaluate(locale.de-de)
  assert.eq(printed(de, decimal("1234.5")), "1.234,50 €")
  assert.eq(printed-fine(de, decimal("0.1234")), "0,1234 €")
  assert.eq(de.currency.code, "EUR")
  let ch = evaluate(locale.de-ch)
  assert.eq(printed(ch, decimal("1234.5")), "CHF 1'234.50")
  assert.eq(ch.currency.code, "CHF")
  assert.eq((ch.normalize.money)(decimal("1.005")), decimal("1.01"))
}

// --- 2. Setting the currency of a built-in locale changes the symbol too ---
#{
  let usd = evaluate(locale.de-de.with((
    region: (currency: (code: "USD", symbol: "$")),
  )))
  assert.eq(usd.currency.code, "USD")
  assert.eq(printed(usd, decimal("1234.5")), "1.234,50 $")
  assert.eq(printed-fine(usd, decimal("0.1234")), "0,1234 $")
  // The number format of the region stays
  let chf = evaluate(locale.de-ch.with((region: (currency: (symbol: "Fr.")))))
  assert.eq(printed(chf, decimal("1234.5")), "Fr. 1'234.50")

  // The decimals of the currency round and print the amounts
  let jpy = evaluate(locale.de-de.with((
    region: (currency: (code: "JPY", symbol: "¥", decimals: 0)),
  )))
  assert.eq((jpy.normalize.money)(decimal("1234.5")), decimal("1235"))
  assert.eq(printed(jpy, decimal("1235")), "1.235 ¥")

  // A formatter of the patch itself is kept
  let own = evaluate(locale.de-de.with(
    (region: (currency: (code: "USD", symbol: "$"))),
    locale.custom.format(currency: x => "USD " + str(x)),
  ))
  assert.eq(printed(own, decimal("12.5")), "USD 12.5")
}

// --- 3. A region builder that sets the currency but no formatters ---
#let region-pl(lang) = (
  meta: (region: "pl"),
  currency: (code: "PLN", symbol: "zł"),
  normalize: (infer-tax: rate => tax.vat(rate)),
  tax: (default-vat: tax.vat(23%)),
)
#let locale-pl = build-locale(base-language, region-pl)
#{
  let pl = evaluate(locale-pl)
  assert.eq(pl.currency.code, "PLN")
  assert.eq(printed(pl, decimal("1230")), "1.230,00 zł")
  assert.eq(printed-fine(pl, decimal("0.1234")), "0,1234 zł")
}

#model-test(locale: locale-pl, model => {
  assert.eq(model.currency, "PLN")
  assert.eq(rules(model), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// --- 4. A region that prints another currency than it states (BT-5) ---
#let region-zloty-format(lang) = (
  meta: (region: "pl"),
  normalize: (infer-tax: rate => tax.vat(rate)),
  format: (
    currency: value => (
      str(calc.round(value, digits: 2)).replace(".", ",") + " zł"
    ),
  ),
  tax: (default-vat: tax.vat(23%)),
)
#model-test(locale: build-locale(base-language, region-zloty-format), model => {
  assert.eq(model.currency, "EUR")
  assert.eq(rules(model), ("IP-PRINT-02",))
  assert.eq(
    diagnostic(model, "IP-PRINT-02").message,
    "The invoice prints amounts in \"zł\" (e.g. \"1 zł\"), but the e-invoice states the currency \"EUR\" (BT-5).",
  )
  // Amounts without any currency sign say nothing else
  let m = model
  m.printed-currency = (symbol: "€", amount: "1,00", price: "1,0000")
  assert.eq(rules(m), ())
  // The code is as good as the symbol, whatever separates the thousands
  m.printed-currency.amount = "EUR 1’000.00"
  assert.eq(rules(m), ())
  // Unit prices may be printed in a subunit, e.g. energy tariffs in cents
  m.printed-currency.price = "100 ct"
  assert.eq(rules(m), ())
  // A symbol with a dot
  m.printed-currency = (symbol: "Bs.", amount: "1,00 Bs.", price: none)
  m.currency = "VES"
  m.profile = resolve-profile("basic-wl", "FR")
  assert.eq(rules(m), ())
  // "€" is no symbol of another currency, even if the locale says so (a
  // locale whose code was changed alone), neither for amounts nor for unit
  // prices
  m.printed-currency = (symbol: "€", amount: "1,00 €", price: none)
  m.currency = "USD"
  assert.eq(rules(m), ("IP-PRINT-02",))
  m.printed-currency = (symbol: "$", amount: "1,00 $", price: "1,00 €")
  assert.eq(rules(m), ("IP-PRINT-02",))
  assert.eq(
    diagnostic(m, "IP-PRINT-02").message,
    "The invoice prints unit prices in \"€\" (e.g. \"1,00 €\"), but the e-invoice states the currency \"USD\" (BT-5).",
  )
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// Unit prices in cents, e.g. of an energy tariff ("32,45 ct"), are no other
// currency
#model-test(
  locale: locale.de-de.with(locale.custom.format(
    currency-fine: value => str(value * 100).replace(".", ",") + " ct",
  )),
  model => {
    assert.eq(model.printed-currency.amount, "1,00 €")
    assert.eq(model.printed-currency.price, "100 ct")
    assert.eq(rules(model), ())
  },
)[
  #line-items[#item([Strom], price: 0.3245, quantity: 1000, unit: "kWh")]
  #payment-goal(days: 14)
  #bank
]

// --- 5. Currencies the EN 16931 validation does not know yet ---
#model-test(model => {
  let m = model
  m.currency = "VES"
  m.printed-currency = (symbol: none, amount: none, price: none)
  assert.eq(rules(m), ("BR-CL-04",))
  assert(diagnostic(m, "BR-CL-04").message.contains("EN 16931 (COMFORT)"))
  // The Factur-X code list of BASIC WL and MINIMUM has them
  m.profile = resolve-profile("basic-wl", "FR")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]
