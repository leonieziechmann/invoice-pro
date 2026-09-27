// An e-invoice states amounts with 2 decimals (BR-DEC-*). A locale that
// rounds money more finely makes amounts the XML can only state rounded, and
// rounded they would be other amounts than the printed ones, which no longer
// add up (BR-CO-10, BR-S-08): that is an error naming the first such amount
// (IP-DEC-02; the builder writes the rounded amounts, so the BR-DEC-* rules
// themselves cannot fail), instead of an invalid XML.

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": bank, diagnostic, model-test, rules

#let money(digits) = locale.de-de.with(locale.custom.normalize(
  money: x => calc.round(x, digits: digits),
))

// --- 1. Money rounded to 3 decimals: 3 x 3.333 is written as 3 x 3.33, but
// with a total of 10.00 ---
#model-test(locale: money(3), model => {
  assert.eq(model.lines.map(l => l.net), (decimal("3.333"),) * 3)
  assert.eq(rules(model), ("IP-DEC-02",))
  let d = diagnostic(model, "IP-DEC-02")
  assert.eq(d.field, "locale")
  assert.eq(
    d.message,
    "An e-invoice states amounts with 2 decimals, but 8 amounts have more, e.g. the line net amount (BT-131) of item 1 (A) is 3.333.",
  )

  // MINIMUM states the totals only
  let m = model
  m.profile = resolve-profile("minimum", "FR")
  assert.eq(rules(m), ("IP-DEC-02",))
  assert(
    diagnostic(m, "IP-DEC-02")
      .message
      .ends-with(
        "the total without VAT (BT-109) is 9.999.",
      ),
  )
})[
  #line-items[
    #item([A], price: 3.3333)
    #item([B], price: 3.3333)
    #item([C], price: 3.3333)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 2. Money rounded to whole units fits into 2 decimals ---
#model-test(locale: money(0), model => {
  assert.eq(rules(model), ())
})[
  #line-items[
    #item([A], price: 3.3333)
    #item([B], price: 3.3333)
    #item([C], price: 3.3333)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 3. Every amount the XML states counts, in the order of the XML ---
#model-test(model => {
  assert.eq(rules(model), ())
  let m = model
  m.allowance-charges.at(0).amount += decimal("0.001")
  assert.eq(rules(m), ("IP-DEC-02",))
  assert.eq(
    diagnostic(m, "IP-DEC-02").message,
    "An e-invoice states amounts with 2 decimals, but the document level allowance (BT-92) is 10.001.",
  )
  let m = model
  m.lines.at(0).charges.at(0).amount += decimal("0.001")
  assert.eq(rules(m), ("IP-DEC-02",))
  let message = diagnostic(m, "IP-DEC-02").message
  assert(message.contains("the line charge (BT-141)"), message: message)
  let m = model
  m.totals.prepaid = decimal("12.345")
  m.totals.due = m.totals.gross - m.totals.prepaid
  assert.eq(rules(m), ("IP-DEC-02",))
  let message = diagnostic(m, "IP-DEC-02").message
  assert(message.contains("the prepaid amount (BT-113)"), message: message)
})[
  #line-items[
    #item([A], price: 100, modifier: surcharge([Express], amount: 5))
    #discount([Coupon], amount: 10)
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 4. A currency with 3 decimals (e.g. KWD) names `currency` ---
#let kwd-items = [
  #line-items[
    #item([A], price: 3.3333)
    #item([B], price: 3.3333)
    #item([C], price: 3.3333)
  ]
  #payment-goal(days: 14)
  #bank
]
#model-test(currency: "KWD", model => {
  assert.eq(rules(model), ("IP-DEC-02",))
  let d = diagnostic(model, "IP-DEC-02")
  assert.eq(d.field, "currency")
  assert(
    d.message.ends-with(
      "is 3.333: the invoice currency \"KWD\" has 3 decimals.",
    ),
    message: d.message,
  )
  assert(d.hint.contains("`zugferd: none`"), message: d.hint)
  assert(d.hint.contains("decimals: 2"), message: d.hint)
})[#kwd-items]
// ... which a locale with the currency and 2 decimals fits into
#model-test(
  locale: locale.en-de.with((
    region: (currency: (code: "KWD", symbol: "KWD", decimals: 2)),
  )),
  model => {
    assert.eq(model.currency, "KWD")
    assert.eq(rules(model), ())
  },
)[#kwd-items]
