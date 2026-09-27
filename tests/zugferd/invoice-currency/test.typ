// The currency of the invoice (`invoice(currency: ..)`): an ISO 4217 code
// that the e-invoice states (BT-5) and the amounts are printed with, with
// its symbol or its code, in the number format of the locale.

#import "/src/lib.typ": *
#import "/src/data/currency.typ": currency-of, with-currency
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region
#import "/src/utils/text.typ": plain-text
#import "/tests/zugferd/harness.typ": (
  bank, buyer-fr, diagnostic, model-test, rules, seller, xml-elements,
  xml-values,
)

#let evaluate(locale) = locale(base-language, base-region)
#let printed(locale, value) = plain-text((locale.format.currency)(value))
#let printed-fine(locale, value) = plain-text(
  (locale.format.currency-fine)(value),
)

// --- 1. The symbol and the decimals of a currency ---
#{
  assert.eq(currency-of("USD"), (code: "USD", symbol: "$", decimals: 2))
  assert.eq(currency-of(" gbp "), (code: "GBP", symbol: "£", decimals: 2))
  assert.eq(currency-of("JPY"), (code: "JPY", symbol: "¥", decimals: 0))
  assert.eq(currency-of("KWD"), (code: "KWD", symbol: "KWD", decimals: 3))
  // Without a common symbol, the code
  assert.eq(currency-of("CHF").symbol, "CHF")
  assert.eq(currency-of("SEK").symbol, "SEK")
}

// --- 2. The locale prints the amounts in the currency ---
#{
  let de = evaluate(locale.de-de)
  let usd = with-currency(de, "usd")
  assert.eq(usd.currency.code, "USD")
  assert.eq(usd.currency.symbol, "$")
  assert.eq(printed(usd, decimal("1234.5")), "1.234,50 $")
  assert.eq(printed-fine(usd, decimal("0.1234")), "0,1234 $")
  // The rounding of amounts stays with the same decimals
  assert.eq((usd.normalize.money)(decimal("1.005")), decimal("1.01"))

  let chf = with-currency(de, "CHF")
  assert.eq(printed(chf, decimal("1234.5")), "1.234,50 CHF")

  // The number format and the position of the symbol of the locale stay
  let ch = evaluate(locale.de-ch)
  assert.eq(printed(with-currency(ch, "EUR"), decimal("1234.5")), "€ 1'234.50")
  let fr = evaluate(locale.fr-fr)
  assert.eq(printed(with-currency(fr, "GBP"), decimal("1234.5")), "1 234,50 £")

  // Other decimals round and print the amounts
  let jpy = with-currency(de, "JPY")
  assert.eq(jpy.currency.decimals, 0)
  assert.eq((jpy.normalize.money)(decimal("1234.5")), decimal("1235"))
  assert.eq(printed(jpy, decimal("1235")), "1.235 ¥")
  assert.eq(printed-fine(jpy, decimal("12.5")), "12,5000 ¥")
  let kwd = with-currency(de, "KWD")
  assert.eq(printed(kwd, decimal("12.5")), "12,500 KWD")

  // The currency of the locale: the locale as it is, with its own formats
  let own = evaluate(locale.de-de.with(locale.custom.format(
    currency: x => "EUR " + str(x),
  )))
  assert.eq(printed(with-currency(own, "EUR"), decimal("12.5")), "EUR 12.5")
  assert.eq(printed(with-currency(ch, "chf"), decimal("1")), "CHF 1.00")
}

// --- 3. The e-invoice states the currency the invoice prints ---
#let consulting = [
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]
#model-test(currency: "USD", model => {
  assert.eq(model.currency, "USD")
  assert.eq(model.currency-field, "currency")
  assert.eq(model.printed-currency, (
    symbol: "$",
    amount: "1,00 $",
    price: "1,00 $",
  ))
  assert.eq(xml-values(model, "ram:InvoiceCurrencyCode"), ("USD",))
  assert.eq(xml-elements(model, "ram:TaxTotalAmount"), (
    "<ram:TaxTotalAmount currencyID=\"USD\">190.00</ram:TaxTotalAmount>",
  ))
  // A credit transfer in another currency is no SEPA credit transfer
  assert(xml-values(model, "ram:TypeCode").contains("30"))
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ())
})[#consulting]

// Without `currency`, the locale's
#model-test(model => {
  assert.eq(model.currency, "EUR")
  assert.eq(model.currency-field, "locale")
})[#consulting]

// A code that is no ISO 4217 code names the input (BR-CL-04)
#model-test(currency: "XYZ", model => {
  assert.eq(rules(model), ("BR-CL-04",))
  let found = diagnostic(model, "BR-CL-04")
  assert.eq(found.field, "currency")
  assert(found.hint.contains("`currency`"))
})[#consulting]

// --- 4. Printed in the currency ---
#invoice(
  theme: () => (
    themes.blank()
      + (
        line-items: (ctx, view, body) => {
          assert.eq(plain-text(view.items.first().total), "1.000,00 $")
          assert.eq(plain-text(view.total.gross), "1.190,00 $")
          []
        },
        bank-details: (ctx, view) => {
          // The EPC-QR code transfers euros only
          assert.eq(view.qr-code.payload, none)
          []
        },
      )
  ),
  locale: locale.de-de,
  currency: "USD",
  sender: seller,
  recipient: buyer-fr,
)[#consulting]
