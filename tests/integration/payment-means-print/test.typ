// The printed invoice states the payment means the e-invoice states: the
// payment goal announces a direct debit or a card payment instead of asking
// for a transfer, a paid invoice says that it is paid and that nothing is
// due, the components print their details, and the bank details show no
// EPC-QR code when the buyer is not asked to transfer the amount. Wrong
// input stops the compilation with a message.

#import "/src/lib.typ": *
#import "/src/themes/base-theme/payment-goal.typ": render-payment-goal
#import "/src/themes/base-theme/payment-means.typ": render-payment-means
#import "/src/themes/base-theme/bank-details.typ": render-bank-details
#import "/tests/integration/payment-reference/harness.typ": find-all, plain

// Records what the layouts print, per scenario.
#let capturing-theme(scenario) = themes.blank.with(
  payment-goal: (ctx, view) => {
    let printed = render-payment-goal(ctx, view)
    [#metadata((scenario, "goal", plain(printed)))<printed>#printed]
  },
  payment-means: (ctx, view) => {
    let printed = render-payment-means(ctx, view)
    [#metadata((scenario, view.kind, plain(printed)))<printed>#printed]
  },
  bank-details: (ctx, view) => {
    let printed = render-bank-details(ctx, view)
    let qr = find-all(printed, image).len() > 0
    [#metadata((
        scenario,
        "bank",
        if qr { "QR" } else { "no QR" },
      ))<printed>#printed]
  },
)

#let test-invoice(scenario, lang: locale.de-de, ..args, body) = invoice(
  theme: capturing-theme(scenario),
  locale: lang,
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
#test-invoice("transfer")[#items #payment-goal(days: 14) #bank]
#test-invoice("direct-debit")[#items #payment-goal(days: 14) #debit]
#test-invoice("direct-debit-due")[#deposit #payment-goal(days: 14) #debit]
#test-invoice("card")[#items #payment-goal() #card]
#test-invoice("card-en", lang: locale.en-de)[
  #items
  #payment-goal(days: 14)
  #card-payment(last4: "987654", kind: "debit")
]
#test-invoice("skonto")[
  #items
  #payment-goal(
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
  #payment-goal(days: 14)
  #debit
  #bank
]
#test-invoice("direct-debit-bank-qr")[
  #items
  #payment-goal(days: 14)
  #debit
  #bank-details(iban: "DE89370400440532013000", qr-code: (display: true))
]
// The currency code of the locale is read as the e-invoice reads it (BT-5):
// "eur" is the euro, so the direct debit is a SEPA direct debit
#let lower-case-euro = locale.de-de.with((region: (currency: (code: "eur"))))
#test-invoice("debit-eur", lang: lower-case-euro)[
  #items
  #payment-goal(days: 14)
  #debit
]
#test-invoice("bank-eur", lang: lower-case-euro)[
  #items
  #payment-goal(days: 14)
  #bank
]
#test-invoice(
  "custom",
  lang: locale.en-de.with({
    import locale.custom: *
    payment(text-card: (sum, deadline) => [Charged: *#sum* #deadline.])
    payment-means(card-number: "Card", paid: (sum, date) => [Paid: #sum.])
  }),
)[#items #payment-goal(days: 3) #card]

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
  assert.eq(
    error[#items #payment-goal(days: 14) #paid(method: "cash")],
    "assertion failed: An invoice that is `paid` has no `payment-goal`: nothing is left to pay. Remove the `payment-goal`.",
  )
  // "eur" is the euro: the creditor identifier of a SEPA direct debit is
  // checked
  assert(
    catch(() => test-invoice("error", lang: lower-case-euro)[
      #items
      #direct-debit(mandate: "M-1", creditor-id: "DE00ZZZ09999999999")
    ]).contains("is not a valid SEPA creditor identifier"),
  )
  assert.eq(
    error[#items #payment-goal(days: 14) #debit #debit],
    "assertion failed: There can only be one `direct-debit` element in the document!",
  )
  assert.eq(
    error[#line-items[#item([A], price: 1) #card]],
    "panicked with: \"Component `card-payment` must NOT be nested within `line-items`.\"",
  )
  assert.eq(
    error[#items #direct-debit(
        mandate: "M-1",
        creditor-id: "DE00ZZZ09999999999",
      )],
    "panicked with: \"direct-debit: the creditor identifier \\\"DE00ZZZ09999999999\\\" is not a valid SEPA creditor identifier (wrong check digits or format). Check it for typos.\"",
  )
  assert.eq(
    error[#items #direct-debit(
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
