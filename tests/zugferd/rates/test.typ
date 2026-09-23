// VAT rates (BT-96, BT-103, BT-119, BT-152) are written with up to four
// decimals, so a rate such as 9.975% is stated as calculated and two rates
// that differ in the third decimal stay apart. A rate the XML cannot state
// is an error.

#import "/src/lib.typ": *
#import "/src/zugferd/xml.typ": fmt-rate
#import "/tests/zugferd/harness.typ": (
  bank, buyer-fr, diagnostic, model-test, rules, xml-values,
)

// --- 1. Formatting: standard rates keep two decimals ---
#{
  assert.eq(fmt-rate(19%), "19.00")
  assert.eq(fmt-rate(decimal("0.055")), "5.50")
  assert.eq(fmt-rate(0%), "0.00")
  assert.eq(fmt-rate(9.975%), "9.975")
  assert.eq(fmt-rate(decimal("0.08125")), "8.125")
  assert.eq(fmt-rate(decimal("0.123456")), "12.3456")
}

// --- 2. A rate with three decimals is stated as calculated (BR-CO-17) ---
#model-test(tax: tax.vat(9.975%), model => {
  assert.eq(rules(model), ())
  assert.eq(xml-values(model, "ram:RateApplicablePercent"), (
    "9.975",
    "9.975",
  ))
  assert.eq(xml-values(model, "ram:CalculatedAmount"), ("4987.50",))
})[
  #line-items[#item([Consulting], price: 50000)]
  #payment-goal(days: 14)
  #bank
]

// --- 3. Two rates that differ in the third decimal stay two VAT groups ---
#model-test(model => {
  assert.eq(rules(model), ())
  assert.eq(xml-values(model, "ram:RateApplicablePercent"), (
    "8.125",
    "8.13",
    "8.125",
    "8.13",
  ))
})[
  #line-items[
    #item([A], price: 100, tax: tax.vat(8.125%))
    #item([B], price: 100, tax: tax.vat(8.13%))
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 4. A rate the XML cannot state is an error (IP-DEC-01), in particular
// if it would be written as the rate of another VAT group ---
#model-test(model => {
  assert.eq(rules(model), ("IP-DEC-01",))
  let d = diagnostic(model, "IP-DEC-01")
  assert.eq(d.field, "tax S 8.125%")
  assert.eq(
    d.message,
    "The VAT rate 8.12501% has more than 4 decimals, so the e-invoice would state it as 8.125%, the rate of another VAT group of category S.",
  )
})[
  #line-items[
    #item([A], price: 100, tax: tax.vat(8.125%))
    #item([B], price: 100, tax: tax.vat(8.12501%))
  ]
  #payment-goal(days: 14)
  #bank
]

// --- 5. The VAT amount is the taxable amount times the stated rate within
// the tolerance of 1 (BR-CO-17) ---
#model-test(model => {
  assert.eq(rules(model), ())
  let m = model
  m.taxes.at(0).amount += decimal("1.01")
  m.totals.tax += decimal("1.01")
  m.totals.gross += decimal("1.01")
  m.totals.due += decimal("1.01")
  m.printed-totals.gross += decimal("1.01")
  assert.eq(rules(m), ("BR-CO-17",))
  // A difference of a cent, e.g. from gross prices, is fine
  let m = model
  m.taxes.at(0).amount += decimal("0.01")
  m.totals.tax += decimal("0.01")
  m.totals.gross += decimal("0.01")
  m.totals.due += decimal("0.01")
  m.printed-totals.gross += decimal("0.01")
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]
