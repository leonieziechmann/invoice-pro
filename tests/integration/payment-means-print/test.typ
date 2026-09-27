// The printed invoice states the payment means the e-invoice states: the
// payment terms announce a direct debit or a card payment instead of asking
// for a transfer, a paid invoice says that it is paid and that nothing is
// due, the components print their details, and the bank details show no
// EPC-QR code when the buyer is not asked to transfer the amount. Wrong
// input stops the compilation with a message; an invalid identifier of a
// direct debit is a data issue that the validation level handles.

#import "/src/lib.typ": *
#import "/tests/integration/payment-reference/harness.typ": find-all, plain

// Records what the default parts print, per scenario.
#let capturing-theme(scenario) = theme.plain.with(
  theme.custom.wrap("payment-terms", (ctx, view, inner) => {
    let printed = inner(ctx, view)
    [#metadata((scenario, "goal", plain(printed)))<printed>#printed]
  }),
  theme.custom.wrap("payment-means", (ctx, view, inner) => {
    let printed = inner(ctx, view)
    [#metadata((scenario, view.kind, plain(printed)))<printed>#printed]
  }),
  theme.custom.wrap("bank-details", (ctx, view, inner) => {
    let printed = inner(ctx, view)
    let qr = find-all(printed, image).len() > 0
    [#metadata((
        scenario,
        "bank",
        if qr { "QR" } else { "no QR" },
      ))<printed>#printed]
  }),
)

// The invoices are bare fixtures (no tax ID of the sender), so validation is
// off.
#let test-invoice(scenario, lang: locale.de-de, ..args, body) = invoice(
  theme: capturing-theme(scenario),
  locale: lang,
  validation: none,
  sender: (name: "Muster GmbH", address: "Hauptstraße 1", city: "10115 Berlin"),
  recipient: (name: "Kunde AG", address: "Domstraße 5", city: "50667 Köln"),
  invoice-nr: "RE-1",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  body,
)

#let items = line-items[#item([Beratung], price: 100, tax: tax.vat(19%))]
#let deposit = line-items[
  #item([Beratung], price: 100, tax: tax.vat(19%))
  #prepayment(19)
]
#let bank = bank-details(bank: "Musterbank", iban: "DE89370400440532013000")
#let debit = direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02120300000000202051",
)
#let card = card-payment(last4: "1234", holder: "Erika Kunde")

// --- 1. Rendered cases, checked below ---
#test-invoice("transfer")[#items #payment-terms(days: 14) #bank]
#test-invoice("direct-debit")[#items #payment-terms(days: 14) #debit]
#test-invoice("direct-debit-due")[#deposit #payment-terms(days: 14) #debit]
#test-invoice("card")[#items #payment-terms() #card]
#test-invoice("card-en", lang: locale.en-de)[
  #items
  #payment-terms(days: 14)
  #card-payment(last4: "987654", kind: "debit")
]
#test-invoice("skonto")[
  #items
  #payment-terms(
    days: 30,
    discount: ((days: 7, percent: 3%), (days: 14, percent: 2%, basis: 100)),
  )
  #bank
]
#test-invoice("paid")[
  #items
  #paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
  #bank
]
#test-invoice("paid-due-en", lang: locale.en-de)[
  #deposit
  #paid(method: "transfer")
  #bank
]
#test-invoice("paid-card")[#items #paid(method: "card") #card]
#test-invoice("direct-debit-bank")[
  #items
  #payment-terms(days: 14)
  #debit
  #bank
]
#test-invoice("direct-debit-bank-qr")[
  #items
  #payment-terms(days: 14)
  #debit
  #bank-details(iban: "DE89370400440532013000", qr-code: (display: true))
]
// A credit note or a self-billed invoice is paid by its sender: the amount
// was paid to the recipient
#test-invoice("paid-credit", document-type: "credit-note")[
  #items
  #paid(method: "transfer", date: datetime(year: 2026, month: 9, day: 1))
  #bank
]
#test-invoice(
  "paid-self-billed-en",
  lang: locale.en-de,
  document-type: "self-billed",
)[#items #paid(method: "cash")]
#for (name, lang) in (
  ("fr", locale.fr-fr),
  ("it", locale.it-it),
  ("es", locale.es-es),
) {
  test-invoice("paid-credit-" + name, lang: lang, document-type: "credit-note")[
    #items
    #paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
  ]
}
// A method of its own is printed next to the details of its component
#test-invoice("paid-card-name")[
  #items
  #paid(method: (code: "54", name: [Visa]))
  #card-payment(last4: "1234", kind: "credit")
]
// The currency code of the locale is read as the e-invoice reads it (BT-5):
// "eur" is the euro, so the direct debit is a SEPA direct debit
#let lower-case-euro = locale.de-de.with((region: (currency: (code: "eur"))))
#test-invoice("debit-eur", lang: lower-case-euro)[
  #items
  #payment-terms(days: 14)
  #debit
]
#test-invoice("bank-eur", lang: lower-case-euro)[
  #items
  #payment-terms(days: 14)
  #bank
]
#test-invoice(
  "custom",
  lang: locale.en-de.with({
    import locale.custom: *
    payment(text-card: (sum, deadline) => [Charged: *#sum* #deadline.])
    payment-means(card-number: "Card", paid: (sum, date) => [Paid: #sum.])
  }),
)[#items #payment-terms(days: 3) #card]
// An invalid identifier of a direct debit is a data issue, like an invalid
// IBAN of the bank details: a draft prints it as given and lists it in its
// report, an e-invoice that reports its problems in the document marks it
// (strict: section 2)
#let bad-debit = direct-debit(
  mandate: "M-1",
  creditor-id: "DE00ZZZ09999999999",
  debtor-iban: "DE00120300000000202051",
)
#test-invoice("debit-draft", validation: "draft")[
  #items
  #payment-terms(days: 14)
  #bad-debit
]
#test-invoice("debit-report", zugferd: "en16931", zugferd-errors: "report")[
  #items
  #payment-terms(days: 14)
  #bad-debit
]

#context {
  // Amounts are printed with a narrow no-break space before the currency.
  let printed = (:)
  for entry in query(<printed>) {
    let (scenario, part, text) = entry.value
    printed.insert(scenario + "/" + part, text.trim().replace("\u{202f}", " "))
  }
  let expect(key, value) = assert.eq(
    printed.at(key, default: none),
    value,
    message: key + ": " + repr(printed.at(key, default: none)),
  )

  // A credit transfer: the sentence asks for it, the bank details show the
  // EPC-QR code
  expect(
    "transfer/goal",
    "Bitte überweisen Sie den Gesamtbetrag in Höhe von 119,00 € innerhalb von 14 Tagen auf das unten angegebene Konto.",
  )
  expect("transfer/bank", "QR")

  // A direct debit announces the debit and prints the mandate
  expect(
    "direct-debit/goal",
    "Der Gesamtbetrag in Höhe von 119,00 € wird innerhalb von 14 Tagen per Lastschrift von Ihrem Konto eingezogen.",
  )
  expect(
    "direct-debit/direct-debit",
    "Zahlungsart: SEPA-Lastschrift\nMandatsreferenz: M-2026-017\nGläubiger-ID: DE98ZZZ09999999999\nIhre IBAN: DE02 1203 0000 0000 2020 51",
  )
  expect(
    "direct-debit-due/goal",
    "Der fällige Betrag in Höhe von 100,00 € wird innerhalb von 14 Tagen per Lastschrift von Ihrem Konto eingezogen.",
  )

  // A card payment
  expect(
    "card/goal",
    "Der Gesamtbetrag in Höhe von 119,00 € wird Ihrer Karte sofort nach Erhalt belastet.",
  )
  expect(
    "card/card",
    "Zahlungsart: Kartenzahlung\nKartennummer: **** 1234\nKarteninhaber:in: Erika Kunde",
  )
  expect(
    "card-en/goal",
    "The total amount of 119,00 € will be charged to your card within 14 days.",
  )
  expect(
    "card-en/card",
    "Payment method: Debit card\nCard number: **** 987654",
  )

  // Cash discounts follow the payment sentence
  expect(
    "skonto/goal",
    "Bitte überweisen Sie den Gesamtbetrag in Höhe von 119,00 € innerhalb von 30 Tagen auf das unten angegebene Konto. Bei Zahlung innerhalb von 7 Tagen gewähren wir 3% Skonto. Bei Zahlung innerhalb von 14 Tagen gewähren wir 2% Skonto auf 100,00 €.",
  )

  // A paid invoice: paid, how, and nothing due; the bank details ask for no
  // transfer
  expect(
    "paid/paid",
    "Der Gesamtbetrag in Höhe von 119,00 € wurde am 01.09.2026 bezahlt.\nZahlungsart: Barzahlung\nFälliger Betrag: 0,00 €",
  )
  expect("paid/bank", "no QR")
  expect(
    "paid-due-en/paid",
    "The amount due of 100,00 € has been paid.\nPayment method: Bank transfer\nAmount Due: 0,00 €",
  )
  // The card details print the method of a card payment
  expect(
    "paid-card/paid",
    "Der Gesamtbetrag in Höhe von 119,00 € wurde bezahlt.\nFälliger Betrag: 0,00 €",
  )

  // Paid by the sender of a credit note or a self-billed invoice
  expect(
    "paid-credit/paid",
    "Den Betrag in Höhe von 119,00 € haben wir Ihnen am 01.09.2026 ausgezahlt.\nZahlungsart: Überweisung\nFälliger Betrag: 0,00 €",
  )
  expect(
    "paid-self-billed-en/paid",
    "We have paid the amount of 119,00 € to you.\nPayment method: Cash\nAmount Due: 0,00 €",
  )
  for (key, sentence) in (
    (
      "paid-credit-fr/paid",
      "Nous vous avons versé le montant de 119,00 € le 01.09.2026.",
    ),
    (
      "paid-credit-it/paid",
      "Vi abbiamo versato l'importo di 119,00 € il 01.09.2026.",
    ),
    (
      "paid-credit-es/paid",
      "Le hemos pagado el importe de 119,00 € el 01.09.2026.",
    ),
  ) {
    assert.eq(
      printed.at(key, default: "").split("\n").first(),
      sentence,
      message: key + ": " + repr(printed.at(key, default: none)),
    )
  }
  // The name of a method of its own next to the card details
  expect(
    "paid-card-name/paid",
    "Der Gesamtbetrag in Höhe von 119,00 € wurde bezahlt.\nZahlungsart: Visa\nFälliger Betrag: 0,00 €",
  )
  expect(
    "paid-card-name/card",
    "Zahlungsart: Kreditkarte\nKartennummer: **** 1234",
  )
  // "eur": a SEPA direct debit, and the bank details show the EPC-QR code
  assert(
    printed
      .at("debit-eur/direct-debit")
      .starts-with(
        "Zahlungsart: SEPA-Lastschrift\n",
      ),
    message: repr(printed.at("debit-eur/direct-debit")),
  )
  expect("bank-eur/bank", "QR")

  // A direct debit does not ask for a transfer: no EPC-QR code, unless it is
  // asked for
  expect("direct-debit-bank/bank", "no QR")
  expect("direct-debit-bank-qr/bank", "QR")

  // An invalid identifier of a direct debit: printed as given in a draft,
  // which lists it in its report (the only draft of this document), and
  // marked in an e-invoice that reports its problems
  expect(
    "debit-draft/direct-debit",
    "Zahlungsart: SEPA-Lastschrift\nMandatsreferenz: M-1\nGläubiger-ID: DE00ZZZ09999999999\nIhre IBAN: DE00 1203 0000 0000 2020 51",
  )
  let draft-ids = query(<ip-issue>).map(it => it.value.id).dedup()
  assert(
    "creditor-id" in draft-ids and "debtor-iban" in draft-ids,
    message: repr(draft-ids),
  )
  expect(
    "debit-report/direct-debit",
    "Zahlungsart: SEPA-Lastschrift\nMandatsreferenz: M-1\nGläubiger-ID: DE00ZZZ09999999999 (invalid)\nIhre IBAN: DE00 1203 0000 0000 2020 51 (invalid)",
  )

  // The texts of the language can be customized, several groups in one block
  expect("custom/goal", "Charged: 119,00 € within 3 days.")
  expect(
    "custom/card",
    "Payment method: Card payment\nCard: **** 1234\nCardholder: Erika Kunde",
  )
}

// --- 2. Wrong input stops the compilation, naming the problem ---
#{
  let error(body) = catch(() => test-invoice("error", body))
  // An invalid identifier of a direct debit stops it under
  // `validation: "strict"` (the fixture's sender gets a VAT ID, so that it is
  // the only problem)
  let strict = (
    validation: "strict",
    sender: (
      name: "Muster GmbH",
      address: "Hauptstraße 1",
      city: "10115 Berlin",
      vat-id: "DE123456789",
    ),
  )
  let strict-error(lang: locale.de-de, body) = catch(() => test-invoice(
    "error",
    lang: lang,
    ..strict,
    body,
  ))
  assert.eq(
    error[#items #payment-terms(days: 14) #paid(method: "cash")],
    "assertion failed: An invoice that is `paid` has no `payment-terms`: nothing is left to pay. Remove the `payment-terms`.",
  )
  // Nor payment terms of its own
  assert.eq(
    catch(() => test-invoice("error", due-date: "sofort")[
      #items #paid(method: "cash")
    ]),
    "assertion failed: An invoice that is `paid` has no payment terms: nothing is left to pay, but `due-date` is a text of payment terms. Remove `due-date`, or give the date the payment was due as a `datetime`.",
  )
  // A due date is the date the payment met
  assert.eq(
    type(test-invoice("error", due-date: datetime(
      year: 2026,
      month: 9,
      day: 15,
    ))[
      #items #paid(method: "cash")
    ]),
    content,
  )
  // A payment means code of its own that its component states otherwise
  assert.eq(
    error[#items #paid(method: (code: "54", name: [Visa])) #card],
    "panicked with: \"paid: `method` names the payment means code \\\"54\\\", but the `card-payment` of the invoice states the code \\\"48\\\". An invoice states one payment means code (BT-81). Set the kind of the card on `card-payment` (`kind: \\\"credit\\\"` for 54, `kind: \\\"debit\\\"` for 55, `auto` for 48) and use a `method` of that code, or leave out `method`.\"",
  )
  assert(
    error[#items #paid(method: (
        code: "30",
        name: [Überweisung],
      )) #bank].contains(
      "the `bank-details` of the invoice states the code \\\"58\\\"",
    ),
  )
  // "eur" is the euro: the creditor identifier of a SEPA direct debit is
  // checked
  assert(
    strict-error(lang: lower-case-euro)[
      #items
      #direct-debit(mandate: "M-1", creditor-id: "DE00ZZZ09999999999")
    ].contains("is not a valid SEPA creditor identifier"),
  )
  assert.eq(
    error[#items #payment-terms(days: 14) #debit #debit],
    "assertion failed: There can only be one `direct-debit` element in the document!",
  )
  assert.eq(
    error[#line-items[#item([A], price: 1) #card]],
    "panicked with: \"Component `card-payment` must NOT be nested within `line-items`.\"",
  )
  assert.eq(
    strict-error[#items #direct-debit(
        mandate: "M-1",
        creditor-id: "DE00ZZZ09999999999",
      )],
    "panicked with: \"direct-debit: the creditor identifier \\\"DE00ZZZ09999999999\\\" is not a valid SEPA creditor identifier (wrong check digits or format). Check it for typos.\"",
  )
  assert.eq(
    strict-error[#items #direct-debit(
        mandate: "M-1",
        creditor-id: "DE98ZZZ09999999999",
        debtor-iban: "DE00120300000000202051",
      )],
    "panicked with: \"direct-debit: the IBAN \\\"DE00 1203 0000 0000 2020 51\\\" of `debtor-iban` is not valid (wrong check digits or format). Check it for typos.\"",
  )
  let message(call) = catch(call)
  assert(
    message(() => direct-debit(creditor-id: "DE98ZZZ09999999999")).contains(
      "direct-debit: the mandate reference is missing.",
    ),
  )
  assert(
    message(() => direct-debit(mandate: "M-1")).contains(
      "direct-debit: the creditor identifier is missing.",
    ),
  )
  for last4 in ("4111 1111 1111 1111", "12", "12a4", none) {
    assert(
      message(() => card-payment(last4: last4)).contains(
        "card-payment: `last4` must be the last 4 digits of the card number",
      ),
      message: repr(last4),
    )
  }
  assert(
    message(() => paid(method: "gold")).contains("paid::method"),
  )
}
