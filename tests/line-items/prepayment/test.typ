#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
  tax-mode: "exclusive",
)

#data-test(test: (ctx, data) => {
  let li = loom.query.find-signal(data, "line-items")
  assert.ne(li, none, message: "line-items signal not found")

  // Taxable base and gross remain untouched by prepayments
  assert.eq(
    li.total.net,
    decimal("1000.00"),
    message: "Net total should be 1000.00, got " + repr(li.total.net),
  )
  assert.eq(
    li.total.gross,
    decimal("1190.00"),
    message: "Gross total should be 1190.00, got " + repr(li.total.gross),
  )

  // Prepaid total: 300 (prepayment 1) + 100 (prepayment 2) + 119 (10% of 1190.00) = 519.00
  assert.eq(
    li.total.prepaid,
    decimal("519.00"),
    message: "Prepaid total should be 519.00, got " + repr(li.total.prepaid),
  )

  // Amount due: 1190.00 - 519.00 = 671.00
  assert.eq(
    li.total.due,
    decimal("671.00"),
    message: "Due total should be 671.00, got " + repr(li.total.due),
  )

  // Prepayment details
  let prepayments = li.item-data.prepayments
  assert.eq(prepayments.len(), 3, message: "Expected 3 prepayments")

  // Prepayment 1: minimal syntax
  assert.eq(prepayments.at(0).amount, decimal("300.00"))
  assert.eq(prepayments.at(0).label, "Prepayment")
  assert.eq(prepayments.at(0).name, none)

  // Prepayment 2: name, date, reference
  assert.eq(prepayments.at(1).amount, decimal("100.00"))
  assert.eq(prepayments.at(1).name, "1. Rate")
  assert.eq(prepayments.at(1).reference, "ADV-999")

  // Prepayment 3: percentage
  assert.eq(prepayments.at(2).amount, decimal("119.00"))
  assert.eq(prepayments.at(2).label, "10% Kaution")

  // Downstream checks (pass 2): payment-goal and bank-details use due amount
  let pg = loom.query.find-signal(data, "payment-goal")
  if pg != none {
    assert.eq(
      pg.total,
      decimal("671.00"),
      message: "payment-goal should use remaining due amount (671.00), got "
        + repr(pg.total),
    )
  }

  let bank = loom.query.find-signal(data, "bank-details")
  if bank != none {
    assert.eq(
      bank.payment-amount,
      decimal("671.00"),
      message: "bank-details should use remaining due amount (671.00), got "
        + repr(bank.payment-amount),
    )
  }
})[
  #line-items[
    #item(
      [Web Design Project],
      price: 1000.00,
      tax: tax.vat(19%),
    )

    // 1. Minimal syntax: #prepayment(amount)
    #prepayment(300)

    // 2. Prepayment with date, name, and reference
    #prepayment(
      100,
      name: "1. Rate",
      date: datetime(year: 2026, month: 8, day: 15),
      reference: "ADV-999",
    )

    // 3. Percentage prepayment (10% of 1190.00 gross = 119.00)
    #prepayment(10%, label: "10% Kaution")
  ]

  #bank-details(
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )

  #payment-goal(days: 14)
]
