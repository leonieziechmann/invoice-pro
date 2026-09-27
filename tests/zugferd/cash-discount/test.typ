// A cash discount (Skonto) of the payment goal: one structure is the note
// the invoice prints and the payment terms of the e-invoice (BT-20), in
// XRechnung in the Skonto syntax of the KoSIT (BR-DE-18), in the other
// profiles as printed.

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, diagnostic, model-test, rules, xml-values,
)

#let xrechnung = (zugferd: "xrechnung", recipient: buyer-de)
#let items = line-items[
  #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
]

// --- 1. One cash discount ---
#model-test(..xrechnung, model => {
  assert.eq(model.payment.discounts, (
    (days: 14, percent: decimal("2.00"), basis: none),
  ))
  // The due date of the payment goal stays BT-9
  assert.eq(model.payment.due-date, datetime(year: 2026, month: 10, day: 1))
  assert.eq(
    model.payment.terms,
    "Bei Zahlung innerhalb von 14 Tagen gewähren wir 2% Skonto.",
  )
  assert.eq(model.payment.terms-xrechnung, "#SKONTO#TAGE=14#PROZENT=2.00#\n")
  assert.eq(model.payment.terms-input, "payment-goal")
  assert.eq(rules(model), ())
  assert.eq(xml-values(model, "ram:Description"), (
    "#SKONTO#TAGE=14#PROZENT=2.00#\n",
  ))

  // The other profiles state the note as printed, e.g. EN 16931 when
  // `zugferd: auto` falls back from XRechnung
  let m = model
  m.profile = resolve-profile("en16931", "DE")
  assert.eq(xml-values(m, "ram:Description"), (
    "Bei Zahlung innerhalb von 14 Tagen gewähren wir 2% Skonto.",
  ))
  assert.eq(rules(m), ())
})[
  #items
  #payment-goal(days: 30, discount: (days: 14, percent: 2%))
  #bank
]

// --- 2. Several steps, with the amount a discount applies to, after the
// textual terms of the payment goal ---
#model-test(..xrechnung, model => {
  assert.eq(
    model.payment.terms-xrechnung,
    "Zahlbar innerhalb von 30 Tagen netto.\n#SKONTO#TAGE=7#PROZENT=3.00#BASISBETRAG=238.00#\n#SKONTO#TAGE=14#PROZENT=2.50#\n",
  )
  assert.eq(
    model.payment.terms,
    "Zahlbar innerhalb von 30 Tagen netto.\nBei Zahlung innerhalb von 7 Tagen gewähren wir 3% Skonto auf 238,00 €.\nBei Zahlung innerhalb von 14 Tagen gewähren wir 2,5% Skonto.",
  )
  assert.eq(rules(model), ())

  // XRechnung states the amount with 2 decimals (BR-DE-18)
  let m = model
  m.payment.discounts.at(0).basis = decimal("238.005")
  assert.eq(rules(m), ("BR-DE-18",))
  assert.eq(diagnostic(m, "BR-DE-18").field, "payment-goal.discount")
})[
  #items
  #payment-goal(
    date: [Zahlbar innerhalb von 30 Tagen netto.],
    discount: (
      (days: 7, percent: 3%, basis: 238),
      (days: 14, percent: 2.5%),
    ),
  )
  #bank
]

// The note in the language of the invoice, with the number format of its
// region
#model-test(locale: locale.en-de, model => {
  assert.eq(
    model.payment.terms,
    "For payment within 10 days, a cash discount of 1,5% is granted.",
  )
})[
  #items
  #payment-goal(days: 30, discount: (days: 10, percent: 1.5%))
  #bank
]

// MINIMUM states no payment terms
#model-test(zugferd: "minimum", model => {
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ("IP-PROFILE-01",))
  assert.eq(
    diagnostic(model, "IP-PROFILE-01").field,
    "payment-goal.discount",
  )
})[
  #items
  #payment-goal(days: 30, discount: (days: 14, percent: 2%))
  #bank
]

// --- 3. Wrong input stops at once, naming the value ---
#{
  let message(discount) = catch(() => payment-goal(
    days: 30,
    discount: discount,
  ))
  assert(
    message((days: 14, percent: 2%, rate: 2%)).contains(
      "`payment-goal::discount` has the unknown key `rate`",
    ),
  )
  assert(
    message((days: 0, percent: 2%)).contains(
      "`payment-goal::discount.days` must be the number of days",
    ),
  )
  assert(
    message(((days: 14, percent: 2%), (days: 7, percent: 2))).contains(
      "`payment-goal::discount.at(1).percent` must be a percentage such as `2%`, got 2",
    ),
  )
  assert(
    message((days: 14, percent: 2.125%)).contains(
      "can have at most 2 decimals",
    ),
  )
  assert(
    message((days: 14, percent: 0%)).contains(
      "must be more than 0% and less than 100%",
    ),
  )
  assert(
    message((14, 2%)).contains("must be a dictionary such as"),
    message: message((14, 2%)),
  )
}
