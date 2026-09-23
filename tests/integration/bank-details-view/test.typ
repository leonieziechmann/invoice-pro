// The data `bank-details` prepares for the `bank-details` part, and the
// default part drawing only these data. The component normalizes IBAN and
// BIC, decides whether an EPC-QR code is generated (shown, invoice in EUR),
// prepares its payload or the problems that prevent it, which stop the
// compilation under `validation: "strict"`, and draws the code from the
// payload (`view.qr`), or a placeholder naming the problems in a draft or
// when they are reported in the document. The part only places it.

#import "/src/lib.typ": *
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region
#import "/src/logic/epc.typ"
#import "/src/utils/bic.typ": bic-valid, normalize-bic
#import "/src/utils/text.typ": plain-text
#import "/tests/integration/payment-reference/harness.typ": find-all, plain

#let valid = "DE75512108001245126199"
#let long-name = "Muster Gesellschaft für Beratung, Entwicklung und Vertrieb mbH & Co. KG"

// --- 1. BIC helpers ---
#{
  assert.eq(normalize-bic("sola dest 600"), "SOLADEST600")
  assert.eq(normalize-bic([sola *dest* 600]), "SOLADEST600")
  assert.eq(normalize-bic(none), "")
  // Every whitespace character goes, as with the class `\s`.
  let reference(value) = upper(plain-text(value).replace(regex("\\s"), ""))
  for value in (
    "sola\u{00A0}dest\t600",
    "sola\u{2028}dest\u{3000}6\u{0085}00\r\n",
    [sola #linebreak() dest #h(1em) 600],
    "  SOLADEST600  ",
    "",
  ) {
    assert.eq(normalize-bic(value), reference(value), message: repr(value))
  }
  assert.eq(normalize-bic("sola\u{00A0}dest\t600"), "SOLADEST600")
  assert(bic-valid("SOLADEST"))
  assert(bic-valid("SOLADEST600"))
  assert(not bic-valid("COBA22XXX"), message: "9 characters")
  assert(not bic-valid("soladest600"), message: "not in electronic format")
  assert(not bic-valid(""))
  assert(not bic-valid(none))
}

// --- 2. The EPC-QR code: payload ---
#{
  let code = epc.qr-code(
    [*Muster* GmbH],
    valid,
    bic: "SOLADEST600",
    reference: "RE-2026-001",
    amount: decimal("119.00"),
  )
  assert.eq(code.problems, ())
  assert.eq(code.payload, (
    beneficiary: "Muster GmbH",
    iban: valid,
    bic: "SOLADEST600",
    amount: 119.0,
    reference: "RE-2026-001",
    text: none,
  ))

  // The code carries a reference or a text, the text wins.
  let code = epc.qr-code("M", valid, reference: "RE-1", text: [Beitrag *2026*])
  assert.eq((code.payload.reference, code.payload.text), (none, "Beitrag 2026"))

  // Empty values are left out; amounts outside 0.01 to 999 999 999.99 are
  // left open for the payer.
  let code = epc.qr-code("M", valid, bic: "", reference: [], amount: 0)
  assert.eq(
    (code.payload.bic, code.payload.reference, code.payload.amount),
    (none, none, none),
  )
  assert.eq(epc.qr-code("M", valid, amount: 0.01).payload.amount, 0.01)
  assert.eq(epc.qr-code("M", valid, amount: -5).payload.amount, none)
  assert.eq(epc.qr-code("M", valid, amount: 1000000000).payload.amount, none)
  assert.eq(epc.qr-code("M", valid).payload.amount, none)
}

// --- 3. The EPC-QR code: problems ---
#{
  let shorts(..args) = epc.qr-code(..args).problems.map(p => p.short)
  let code = epc.qr-code(
    "",
    "DE00512108001245126199",
    bic: "COBA22XXX",
    reference: "RE-2026-001/Projekt-Nordstern/Phase-2",
  )
  assert.eq(code.payload, none)
  assert.eq(code.problems.map(p => p.short), (
    "invalid IBAN",
    "account holder missing",
    "invalid BIC",
    "reference too long",
  ))
  assert.eq(
    code.problems.first().message,
    "the IBAN \"DE00 5121 0800 1245 1261 99\" is not valid",
  )
  assert.eq(shorts("M", ""), ("IBAN missing",))
  assert.eq(shorts("#sender.name", valid), ("account holder missing",))
  // The limits count bytes: 70 for the account holder, 140 for the text.
  assert.eq(shorts("x" * 70, valid), ())
  assert.eq(shorts("ü" * 36, valid), ("account holder too long",))
  assert.eq(shorts("M", valid, text: "x" * 140), ())
  assert.eq(shorts("M", valid, text: "x" * 141), ("reference text too long",))
  // A reference that the text replaces does not count.
  assert.eq(shorts("M", valid, reference: "x" * 36, text: "T"), ())
}

// --- 4. The view of the layout ---

// Records the view the part receives and what the default part draws.
#let capturing-theme = theme.plain.with(theme.custom.wrap(
  "bank-details",
  (ctx, view, inner) => {
    let printed = inner(ctx, view)
    [#metadata((view: view, printed: printed))<bank-details>#printed]
  },
))

// Strict by default: every problem stops the compilation with its message.
#let test-invoice(
  theme: capturing-theme,
  sender-name: "Muster GmbH",
  region-locale: locale.de-de,
  zugferd: none,
  zugferd-errors: "panic",
  validation: "strict",
  ..bank,
) = invoice(
  theme: theme,
  locale: region-locale,
  zugferd: zugferd,
  zugferd-errors: zugferd-errors,
  validation: validation,
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
  #payment-terms(days: 14)
  #bank-details(bank: "Musterbank", ..bank)
]

// IBAN and BIC as typed; the view carries them in electronic format.
#test-invoice(iban: "de75 5121 0800 1245 1261 99", bic: "sola dest 600")
// Swiss francs: no EPC-QR code (SEPA is euro only), also no check of it.
#test-invoice(region-locale: locale.de-ch, iban: valid, bic: "COBA22XXX")
// No QR code wanted.
#test-invoice(sender-name: long-name, iban: valid, qr-code: (display: false))
// "report": the problems reach the part, which draws the placeholder of
// `view.qr` (the checks of the invoice data are off, which would stop them).
#test-invoice(
  sender-name: long-name,
  iban: valid,
  bic: "COBA22XXX",
  zugferd: "en16931",
  zugferd-errors: "report",
  validation: none,
)

#context {
  let captured = query(<bank-details>).map(it => it.value)
  assert.eq(captured.len(), 4)
  let (euro, franc, hidden, reported) = captured
  let images(it) = find-all(it.printed, image)

  assert.eq(euro.view.sender.iban, valid)
  assert.eq(euro.view.sender.bic, "SOLADEST600")
  assert.eq(euro.view.qr-code.problems, ())
  assert.eq(euro.view.qr-code.payload, (
    beneficiary: "Muster GmbH",
    iban: valid,
    bic: "SOLADEST600",
    amount: 119.0,
    reference: "RE-2026-001",
    text: none,
  ))
  let epc-lines = images(euro).first().alt.split("\n")
  assert.eq(epc-lines.slice(4, 8), (
    "SOLADEST600",
    "Muster GmbH",
    valid,
    "EUR119.00",
  ))
  assert(plain(euro.printed).contains("BIC: SOLADEST600"))
  // v2: the IBAN grouped in fours (non-breaking), and the one reference
  assert.eq(
    euro.view.iban.text,
    "DE75\u{A0}5121\u{A0}0800\u{A0}1245\u{A0}1261\u{A0}99",
  )
  assert.eq(euro.view.payment-reference, "RE-2026-001")

  for it in (franc, hidden) {
    assert.eq((it.view.qr-code.payload, it.view.qr-code.problems), (none, ()))
    assert.eq(images(it), ())
    assert(not plain(it.printed).contains("No EPC-QR code"))
  }
  assert.eq(franc.view.qr-code.display, true)
  assert.eq(hidden.view.qr-code.display, false)

  assert.eq(reported.view.report-problems, true)
  assert.eq(reported.view.qr-code.payload, none)
  assert.eq(reported.view.qr-code.problems.map(p => p.short), (
    "account holder too long",
    "invalid BIC",
  ))
  assert.eq(images(reported), ())
  assert(
    plain(reported.printed).contains(
      "No EPC-QR code: account holder too long, invalid BIC",
    ),
  )
}

// --- 5. The component stops, whatever the part draws ---
#{
  let text-only = theme.plain.with(theme.custom.part(
    "bank-details",
    (ctx, view) => [#view.sender.iban],
  ))
  assert.eq(
    catch(() => test-invoice(
      theme: text-only,
      sender-name: long-name,
      iban: valid,
    )),
    "panicked with: "
      + repr(
        "bank-details: the EPC-QR code cannot be generated: the account holder name \""
          + long-name
          + "\" is too long for the EPC-QR code (at most 70 bytes, non-ASCII characters count twice or more); set the account name as registered at the bank with `name` on `bank-details`. Hide it with `qr-code: (display: false)` on `bank-details` if it is not needed.",
      ),
  )
  // Without the QR code, the part gets the bank details.
  assert.eq(
    catch(() => test-invoice(
      theme: text-only,
      sender-name: long-name,
      iban: valid,
      qr-code: (display: false),
    )),
    none,
  )
}

// --- 6. The default part draws what the view holds, nothing else ---
#{
  let ctx = (
    locale: (locale.de-de)(base-language, base-region),
    theme: theme.resolve(theme.plain, validation: none),
  )
  let view = (
    sender: (
      name: "Muster GmbH",
      bank: "Musterbank",
      iban: valid,
      iban-valid: true,
      bic: "",
    ),
    iban: (value: valid, text: "DE75 5121 0800 1245 1261 99", valid: true),
    qr-code: (size: auto, display: true, payload: none, problems: ()),
    qr: none,
    reference: "RE-2026-001",
    text: none,
    payment-reference: "RE-2026-001",
    show-reference: true,
    report-problems: false,
    payment-amount: decimal("119"),
  )
  let draw(..fields) = theme.parts.bank-details(ctx, view + fields.named())

  // No code in the view: none is drawn, although it is displayed.
  assert.eq(find-all(draw(), image), ())
  assert(plain(draw()).contains("IBAN: DE75 5121 0800 1245 1261 99"))
  assert(plain(draw()).contains("Verwendungszweck: RE-2026-001"))

  // The code of the view is drawn at the size of the theme (25 mm); the
  // component builds it from the payload, or the placeholder naming the
  // problems.
  assert(
    plain(draw(qr: size => [QR #repr(size)])).contains("QR " + repr(25mm)),
  )

  // An invalid IBAN is noted next to it only when the e-invoice reports its
  // problems in the document; a draft lists it in its report.
  let invalid = (value: "DE00", text: "DE00", valid: false)
  assert(not plain(draw(iban: invalid)).contains("(invalid)"))
  assert(
    plain(draw(iban: invalid, report-problems: true)).contains("(invalid)"),
  )
}
