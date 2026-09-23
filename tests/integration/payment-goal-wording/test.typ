// The payment-terms sentence must describe the amount it prints: without
// prepayments it asks for the total amount (`payment.text`), with prepayments
// it asks for the remaining amount due (`payment.text-due`).

#import "/src/lib.typ": *
#import "/src/locale/lang/lang.typ"
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

// Tags each rendered payment-terms sentence with its view and text so the
// final layout can be queried per scenario. The wrap renders the default part.
// The invoices are bare fixtures (several in one document), so validation is
// off.
#let captured-invoice(scenario, loc: test-locale, body) = invoice(
  theme: theme.plain.with(
    theme.custom.wrap("payment-terms", (ctx, view, inner) => {
      let sentence = inner(ctx, view)
      [#sentence#metadata((
          scenario: scenario,
          view: view,
          text: plain(sentence),
        )) <payment-terms-wording>]
    }),
  ),
  locale: loc,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  validation: none,
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
  #payment-terms(days: 14)
]

// 2. With prepayment: remaining amount due, "amount due" wording
#captured-invoice("prepayment")[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
    #prepayment(500)
  ]
  #payment-terms(days: 14)
]

// 3. A zero prepayment leaves the gross total payable, so the sentence keeps
//    the "total amount" wording that matches the printed number
#captured-invoice("zero-prepayment")[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
    #prepayment(0)
  ]
  #payment-terms(days: 14)
]

// 4./5. German locale without and with prepayment
#captured-invoice("no-prepayment-de", loc: locale.de-de)[
  #line-items[
    #item([Beratung], price: 1000.00, tax: tax.vat(19%))
  ]
  #payment-terms(days: 14)
]

#captured-invoice("prepayment-de", loc: locale.de-de)[
  #line-items[
    #item([Beratung], price: 1000.00, tax: tax.vat(19%))
    #prepayment(500)
  ]
  #payment-terms(days: 14)
]

// 6./7. `locale.custom.payment(text-due: ..)` overrides the prepayment wording
#captured-invoice("no-prepayment-custom", loc: custom-locale)[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
  ]
  #payment-terms(days: 14)
]

#captured-invoice("prepayment-custom", loc: custom-locale)[
  #line-items[
    #item([Consulting], price: 1000.00, tax: tax.vat(19%))
    #prepayment(500)
  ]
  #payment-terms(days: 14)
]

#context {
  let captured(scenario) = {
    let found = query(<payment-terms-wording>)
      .map(m => m.value)
      .filter(v => v.scenario == scenario)
    assert.eq(
      found.len(),
      1,
      message: scenario
        + ": expected 1 rendered payment-terms sentence, got "
        + repr(found.len()),
    )
    found.first()
  }

  let expect(scenario, amount-kind, amount, sentence) = {
    let pt = captured(scenario)
    assert.eq(
      pt.view.amount-kind,
      amount-kind,
      message: scenario
        + ": amount-kind: expected "
        + repr(amount-kind)
        + ", got "
        + repr(pt.view.amount-kind),
    )
    assert.eq(
      pt.view.amount.value,
      amount,
      message: scenario
        + ": amount: expected "
        + repr(amount)
        + ", got "
        + repr(pt.view.amount.value),
    )
    assert.eq(
      pt.text,
      sentence,
      message: scenario
        + ": sentence: expected "
        + repr(sentence)
        + ", got "
        + repr(pt.text),
    )
  }

  expect(
    "no-prepayment",
    "total",
    decimal("1190.00"),
    "Please transfer the total amount of 1.190,00\u{202f}€ within 14 days to the account listed below.",
  )
  expect(
    "prepayment",
    "amount-due",
    decimal("690.00"),
    "Please transfer the amount due of 690,00\u{202f}€ within 14 days to the account listed below.",
  )
  expect(
    "zero-prepayment",
    "total",
    decimal("1190.00"),
    "Please transfer the total amount of 1.190,00\u{202f}€ within 14 days to the account listed below.",
  )
  expect(
    "no-prepayment-de",
    "total",
    decimal("1190.00"),
    "Bitte überweisen Sie den Gesamtbetrag in Höhe von 1.190,00\u{202f}€ innerhalb von 14 Tagen auf das unten angegebene Konto.",
  )
  expect(
    "prepayment-de",
    "amount-due",
    decimal("690.00"),
    "Bitte überweisen Sie den fälligen Betrag in Höhe von 690,00\u{202f}€ innerhalb von 14 Tagen auf das unten angegebene Konto.",
  )
  expect(
    "no-prepayment-custom",
    "total",
    decimal("1190.00"),
    "Please pay 1.190,00\u{202f}€ within 14 days.",
  )
  expect(
    "prepayment-custom",
    "amount-due",
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
