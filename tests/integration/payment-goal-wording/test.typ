// The payment-goal sentence must describe the amount it prints: without
// prepayments it asks for the total amount (`payment.text`), with prepayments
// it asks for the remaining amount due (`payment.text-due`).

#import "/src/lib.typ": *
#import "/src/locale/lang/lang.typ"
#import "/src/themes/base-theme/payment-goal.typ": render-payment-goal
#import "/tests/test-locale.typ": test-locale

// Flattens rendered content into a plain string for exact comparisons.
#let plain(it) = {
  if it == none { "" } else if type(it) == str { it } else if it.has("text") {
    it.text
  } else if it.has("children") {
    it.children.map(plain).sum(default: "")
  } else if it.has("body") { plain(it.body) } else if it.func() == smartquote {
    if it.at("double", default: true) { "\"" } else { "'" }
  } else if it == [ ] { " " } else { "" }
}

// Tags each rendered payment goal with its view and sentence so the final
// layout can be queried per scenario.
#let captured-invoice(scenario, loc: test-locale, body) = invoice(
  theme: themes.blank.with(
    payment-goal: (ctx, view) => {
      let sentence = render-payment-goal(ctx, view)
      [#sentence#metadata((
          scenario: scenario,
          view: view,
          text: plain(sentence),
        )) <payment-goal-wording>]
    },
  ),
  locale: loc,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  body,
)

#let custom-locale = locale.en-de.with({
  import locale.custom: *

  payment(
    text: (sum, deadline) => [Please pay *#sum* #deadline.],
    text-due: (sum, deadline) => [Please pay the remaining *#sum* #deadline.],
  )
})

// 1. Without prepayment: gross total, "total amount" wording
#captured-invoice("no-prepayment")[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
  ]
  #payment-goal(days: 14)
]

// 2. With prepayment: remaining amount due, "amount due" wording
#captured-invoice("prepayment")[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
    #prepayment(500)
  ]
  #payment-goal(days: 14)
]

// 3. A zero prepayment leaves the gross total payable, so the sentence keeps
//    the "total amount" wording that matches the printed number
#captured-invoice("zero-prepayment")[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
    #prepayment(0)
  ]
  #payment-goal(days: 14)
]

// 4./5. German locale without and with prepayment
#captured-invoice("no-prepayment-de", loc: locale.de-de)[
  #line-items[
    #item([Beratung], price: 1000.00, tax: tax.vat(19%))
  ]
  #payment-goal(days: 14)
]

#captured-invoice("prepayment-de", loc: locale.de-de)[
  #line-items[
    #item([Beratung], price: 1000.00, tax: tax.vat(19%))
    #prepayment(500)
  ]
  #payment-goal(days: 14)
]

// 6./7. `locale.custom.payment(text-due: ..)` overrides the prepayment wording
#captured-invoice("no-prepayment-custom", loc: custom-locale)[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
  ]
  #payment-goal(days: 14)
]

#captured-invoice("prepayment-custom", loc: custom-locale)[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
    #prepayment(500)
  ]
  #payment-goal(days: 14)
]

#context {
  let captured(scenario) = {
    let found = query(<payment-goal-wording>)
      .map(m => m.value)
      .filter(v => v.scenario == scenario)
    assert.eq(
      found.len(),
      1,
      message: scenario
        + ": expected 1 rendered payment goal, got "
        + repr(found.len()),
    )
    found.first()
  }

  let expect(scenario, has-prepayments, total, sentence) = {
    let pg = captured(scenario)
    assert.eq(
      pg.view.has-prepayments,
      has-prepayments,
      message: scenario
        + ": has-prepayments: expected "
        + repr(has-prepayments)
        + ", got "
        + repr(pg.view.has-prepayments),
    )
    assert.eq(
      pg.view.total,
      total,
      message: scenario
        + ": total: expected "
        + repr(total)
        + ", got "
        + repr(pg.view.total),
    )
    assert.eq(
      pg.text,
      sentence,
      message: scenario
        + ": sentence: expected "
        + repr(sentence)
        + ", got "
        + repr(pg.text),
    )
  }

  expect(
    "no-prepayment",
    false,
    decimal("1190.00"),
    "Please transfer the total amount of 1.190,00\u{202f}€ within 14 days to the account listed below.",
  )
  expect(
    "prepayment",
    true,
    decimal("690.00"),
    "Please transfer the amount due of 690,00\u{202f}€ within 14 days to the account listed below.",
  )
  expect(
    "zero-prepayment",
    false,
    decimal("1190.00"),
    "Please transfer the total amount of 1.190,00\u{202f}€ within 14 days to the account listed below.",
  )
  expect(
    "no-prepayment-de",
    false,
    decimal("1190.00"),
    "Bitte überweisen Sie den Gesamtbetrag in Höhe von 1.190,00\u{202f}€ innerhalb von 14 Tagen auf das unten angegebene Konto.",
  )
  expect(
    "prepayment-de",
    true,
    decimal("690.00"),
    "Bitte überweisen Sie den fälligen Betrag in Höhe von 690,00\u{202f}€ innerhalb von 14 Tagen auf das unten angegebene Konto.",
  )
  expect(
    "no-prepayment-custom",
    false,
    decimal("1190.00"),
    "Please pay 1.190,00\u{202f}€ within 14 days.",
  )
  expect(
    "prepayment-custom",
    true,
    decimal("690.00"),
    "Please pay the remaining 690,00\u{202f}€ within 14 days.",
  )
}

// Every language provides a dedicated amount-due phrasing
#{
  let phrases = (
    (lang.de, "den fälligen Betrag"),
    (lang.en, "the amount due"),
    (lang.fr, "le montant restant dû"),
    (lang.it, "l'importo dovuto"),
    (lang.es, "el importe pendiente"),
  )
  for (language, phrase) in phrases {
    let sentence = plain((language.payment.text-due)("1 €", "soon"))
    assert(
      sentence.contains(phrase),
      message: language.meta.lang
        + ": text-due: expected to contain "
        + repr(phrase)
        + ", got "
        + repr(sentence),
    )
  }
}
