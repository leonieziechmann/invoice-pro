// The data `bank-details` prepares for the theme layout, and the base layout
// drawing only these data. The component normalizes IBAN and BIC, decides
// whether an EPC-QR code is generated (shown, invoice in EUR), prepares its
// payload or the problems that prevent it, and stops the compilation for
// such problems unless they are reported in the document. The layout draws
// the code from the payload, or a placeholder naming the problems.

#import "/src/lib.typ": *
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region
#import "/src/logic/epc.typ"
#import "/src/utils/bic.typ": bic-valid, normalize-bic
#import "/src/themes/base-theme/bank-details.typ": render-bank-details
#import "/tests/integration/payment-reference/harness.typ": find-all, plain

#let valid = "DE75512108001245126199"
#let long-name = "Muster Gesellschaft für Beratung, Entwicklung und Vertrieb mbH & Co. KG"

// --- 1. BIC helpers ---
#{
  assert.eq(normalize-bic("sola dest 600"), "SOLADEST600")
  assert.eq(normalize-bic([sola *dest* 600]), "SOLADEST600")
  assert.eq(normalize-bic(none), "")
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

// Records the view the layout receives and what the base layout draws.
#let capturing-theme = themes.blank.with(
  bank-details: (ctx, view) => {
    let printed = render-bank-details(ctx, view)
    [#metadata((view: view, printed: printed))<bank-details>#printed]
  },
)

#let test-invoice(
  theme: capturing-theme,
  sender-name: "Muster GmbH",
  region-locale: locale.de-de,
  zugferd: none,
  zugferd-errors: "panic",
  ..bank,
) = invoice(
  theme: theme,
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

// IBAN and BIC as typed; the view carries them in electronic format.
#test-invoice(iban: "de75 5121 0800 1245 1261 99", bic: "sola dest 600")
// Swiss francs: no EPC-QR code (SEPA is euro only), also no check of it.
#test-invoice(region-locale: locale.de-ch, iban: valid, bic: "COBA22XXX")
// No QR code wanted.
#test-invoice(sender-name: long-name, iban: valid, qr-code: (display: false))
// "report": the problems reach the layout, which draws a placeholder.
#test-invoice(
  sender-name: long-name,
  iban: valid,
  bic: "COBA22XXX",
  zugferd: "en16931",
  zugferd-errors: "report",
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

// --- 5. The component stops, whatever the layout draws ---
#{
  let text-only = themes.blank.with(bank-details: (ctx, view) => [
    #view.sender.iban
  ])
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
  // Without the QR code, the layout gets the bank details.
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

// --- 6. The base layout draws what the view holds, nothing else ---
#{
  let ctx = (locale: (locale.de-de)(base-language, base-region))
  let view = (
    sender: (
      name: "Muster GmbH",
      bank: "Musterbank",
      iban: valid,
      iban-valid: true,
      bic: "",
    ),
    qr-code: (size: 5em, display: true, payload: none, problems: ()),
    reference: "RE-2026-001",
    text: none,
    show-reference: true,
    report-problems: false,
    payment-amount: decimal("119"),
  )
  let draw(qr-code) = render-bank-details(
    ctx,
    view + (qr-code: view.qr-code + qr-code),
  )

  // No payload, no problems: no code, although it is displayed.
  assert.eq(find-all(draw((:)), image), ())

  // The code shows exactly the payload.
  let payload = (
    beneficiary: "Beneficiary",
    iban: valid,
    bic: none,
    amount: none,
    reference: none,
    text: "Text",
  )
  let codes = find-all(draw((payload: payload)), image)
  assert.eq(codes.len(), 1)
  assert.eq(codes.first().alt.split("\n").slice(4, 11), (
    "",
    "Beneficiary",
    valid,
    "",
    "",
    "",
    "Text",
  ))

  // Problems are named by the placeholder; the layout does not decide
  // whether they stop the compilation.
  let placeholder = draw((
    problems: ((short: "invalid BIC", message: "the BIC is not valid"),),
  ))
  assert.eq(find-all(placeholder, image), ())
  assert(plain(placeholder).contains("No EPC-QR code: invalid BIC"))
}
