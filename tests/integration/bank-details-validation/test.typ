// The IBAN of `bank-details` is checked independently of the theme and of the
// EPC-QR code: a wrong IBAN stops the compilation with a message naming it,
// or, with `zugferd-errors: "report"`, is marked in the document instead. The
// EPC-QR code is only generated when it is shown, from the plain text of the
// account holder, so styled or multi-line sender names work.

#import "/src/lib.typ": *
#import "/src/themes/base-theme/bank-details.typ": render-bank-details
#import "/src/utils/iban.typ": format-iban, iban-valid, normalize-iban
#import "/tests/integration/payment-reference/harness.typ": find-all, plain

// --- 1. IBAN helpers ---
#{
  assert.eq(
    normalize-iban("de89 3704 0044 0532 0130 00"),
    "DE89370400440532013000",
  )
  assert.eq(normalize-iban(none), "")
  assert(iban-valid("DE89370400440532013000"))
  assert(iban-valid("NO9386011117947"))
  assert(not iban-valid("DE00370400440532013000"), message: "check digits")
  assert(not iban-valid("DE89 3704 0044 0532 0130 00"), message: "spaces")
  assert(not iban-valid(""))
  assert(not iban-valid("DE89"))
  assert(not iban-valid(none))
  assert.eq(
    format-iban("DE89370400440532013000"),
    "DE89 3704 0044 0532 0130 00",
  )
  assert.eq(format-iban(""), "")
}

// Records the printed bank details and the rules of a report.
#let capturing-theme = themes.blank.with(
  bank-details: (ctx, view) => {
    let printed = render-bank-details(ctx, view)
    [#metadata(printed)<bank-details>#printed]
  },
  zugferd-report: (ctx, result) => [#metadata(
    result.diagnostics.map(d => d.rule),
  )<report>],
)

#let test-invoice(
  sender-name: "Muster GmbH",
  region-locale: locale.de-de,
  zugferd: none,
  zugferd-errors: "panic",
  ..bank,
) = invoice(
  theme: capturing-theme,
  locale: region-locale,
  zugferd: zugferd,
  zugferd-errors: zugferd-errors,
  sender: (
    name: sender-name,
    address: "Hauptstraße 1",
    city: "10115 Berlin",
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Muster",
      phone: "+49 30 123456",
      email: "max@muster.de",
    ),
  ),
  recipient: (
    name: "Client SARL",
    address: "12 Rue de la Paix",
    city: "75002 Paris",
    country: country.fr,
    vat-id: "FR40303265045",
  ),
  invoice-nr: "RE-2026-001",
  date: datetime(year: 2026, month: 7, day: 1),
)[
  #line-items[#item([Beratung], price: 100, tax: tax.vat(19%))]
  #payment-goal(days: 14)
  #bank-details(bank: "Musterbank", ..bank)
]

// The message of the compiler error, `none` if the invoice compiles.
#let error(..args) = catch(() => test-invoice(..args))
#let panicked(message) = "panicked with: " + repr(message)

#let valid = "DE89370400440532013000"
#let invalid = "DE00370400440532013000"

// --- 2. An invalid or missing IBAN is named, with or without QR code ---
#{
  let expected = panicked(
    "bank-details: the IBAN \"DE00 3704 0044 0532 0130 00\" is not valid (wrong check digits or format). Check it for typos.",
  )
  assert.eq(error(iban: invalid), expected)
  assert.eq(error(iban: invalid, qr-code: (display: false)), expected)
  // Outside the euro area there is no EPC-QR code; the IBAN is checked anyway.
  assert.eq(error(iban: invalid, region-locale: locale.de-ch), expected)
  // The printed invoice would be wrong as well, so the bank details stop the
  // compilation before the e-invoice reports it (IP-PAY-01, in XRechnung
  // BR-DE-19), also when its problems are ignored.
  assert.eq(error(iban: invalid, zugferd: "en16931"), expected)
  assert.eq(
    error(iban: invalid, zugferd: "en16931", zugferd-errors: "ignore"),
    expected,
  )
  assert.eq(
    error(),
    panicked(
      "bank-details: the IBAN is missing. Set `iban` on `bank-details`.",
    ),
  )
}

// --- 3. What the EPC-QR code cannot carry is named as well ---
#{
  let long-name = "Muster Gesellschaft für Beratung, Entwicklung und Vertrieb mbH & Co. KG"
  let message(problem) = panicked(
    "bank-details: the EPC-QR code cannot be generated: "
      + problem
      + ". Hide it with `qr-code: (display: false)` on `bank-details` if it is not needed.",
  )
  assert.eq(
    error(sender-name: long-name, iban: valid),
    message(
      "the account holder name \""
        + long-name
        + "\" is too long for the EPC-QR code (at most 70 bytes, non-ASCII characters count twice or more); set the account name as registered at the bank with `name` on `bank-details`",
    ),
  )
  assert.eq(
    error(iban: valid, bic: "COBA22XXX"),
    message("the BIC \"COBA22XXX\" is not valid (8 or 11 letters and digits)"),
  )
  let reference = "RE-2026-001/Projekt-Nordstern/Phase-2"
  assert.eq(
    error(iban: valid, reference: reference),
    message(
      "the payment reference \""
        + reference
        + "\" is too long for the EPC-QR code (at most 35 bytes, non-ASCII characters count twice or more); use `text` on `bank-details` for a longer, unstructured reference",
    ),
  )
  // Without the QR code, nothing of this matters.
  let hidden = (qr-code: (display: false))
  assert.eq(error(sender-name: long-name, iban: valid, ..hidden), none)
  assert.eq(error(iban: valid, bic: "COBA22XXX", ..hidden), none)
}

// --- 4. Rendered cases, checked below ---

// Styled sender name, IBAN and BIC with spaces and in lower case
#test-invoice(
  sender-name: [*Muster* _GmbH_ #h(1em) & Co. KG],
  iban: "de89 3704 0044 0532 0130 00",
  bic: "cobadeff xxx",
)
// Sender name in several lines
#test-invoice(
  sender-name: ("Muster GmbH", "Abteilung Vertrieb"),
  iban: valid,
)
// Styled sender name without QR code
#test-invoice(
  sender-name: [*Muster* GmbH],
  iban: valid,
  qr-code: (display: false),
)
// "report": the invalid IBAN is marked and reported instead of failing
#test-invoice(
  iban: invalid,
  zugferd: "en16931",
  zugferd-errors: "report",
)
// "report": what the QR code cannot carry is named by its placeholder
#test-invoice(
  sender-name: "Muster Gesellschaft für Beratung, Entwicklung und Vertrieb mbH & Co. KG",
  iban: valid,
  bic: "COBA22XXX",
  zugferd: "en16931",
  zugferd-errors: "report",
)

#context {
  let printed = query(<bank-details>).map(it => it.value)
  assert.eq(printed.len(), 5)
  let lines(it) = plain(it).split("\n").map(line => line.trim())
  let payload(it) = find-all(it, image).map(qr => qr.alt.split("\n"))

  // The QR code carries the plain text of what is printed and of the XML.
  let (first, second, hidden, reported, placeholder) = printed
  assert(lines(first).contains("IBAN: DE89 3704 0044 0532 0130 00"))
  assert(lines(first).contains("BIC: COBADEFFXXX"))
  let epc = payload(first).first()
  assert.eq(epc.at(4), "COBADEFFXXX", message: "EPC BIC")
  assert.eq(epc.at(5), "Muster GmbH & Co. KG", message: "EPC beneficiary")
  assert.eq(epc.at(6), valid, message: "EPC IBAN")

  // The account holder is the sender name on one line, as in the XML (BT-27).
  assert.eq(
    lines(second).first(),
    "Kontoinhaber:in: Muster GmbH, Abteilung Vertrieb",
  )
  assert.eq(payload(second).first().at(5), "Muster GmbH, Abteilung Vertrieb")

  assert.eq(payload(hidden), ())

  assert.eq(payload(reported), ())
  assert(
    lines(reported).contains("IBAN: DE00 3704 0044 0532 0130 00 (invalid)"),
  )
  assert(plain(reported).contains("No EPC-QR code: invalid IBAN"))
  // An invalid IBAN is an error of the e-invoice, so its XML is only a draft.
  assert.eq(query(<report>).map(it => it.value), (("IP-PAY-01",),))

  assert.eq(payload(placeholder), ())
  assert(
    plain(placeholder).contains(
      "No EPC-QR code: account holder too long, invalid BIC",
    ),
  )
}
