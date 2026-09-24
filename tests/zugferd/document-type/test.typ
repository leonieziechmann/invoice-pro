// The document type (`document-type`, BT-3): its code and printed title, the
// subject that names another kind of document (IP-DOC-01), the types
// XRechnung allows (BR-DE-17), the sign of the amounts of credit notes, the
// payment direction of credit notes and self-billed invoices, and the party
// roles of a self-billed invoice, which the buyer issues.

#import "/src/lib.typ": *
#import "/src/logic/document-type.typ": resolve-document-type, sender-pays
#import "/src/zugferd/document.typ": title-kind
#import "/src/locale/lang/lang.typ" as languages
#import "/src/zugferd/zugferd.typ": process-zugferd
#import "/src/utils/text.typ": plain-text
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, buyer-fr, diagnostic, model-test, rules, seller, xml-values,
)
#import "/tests/data-test.typ": data-test, loom

// --- 1. Named types and UNTDID 1001 codes ---
#{
  let resolve(value) = {
    let d = resolve-document-type(value)
    (d.code, d.title, d.credit, d.self-billed, d.sender-pays)
  }
  assert.eq(resolve(auto), ("380", "invoice", false, false, false))
  assert.eq(resolve("invoice"), ("380", "invoice", false, false, false))
  assert.eq(resolve("credit-note"), ("381", "credit-note", true, false, true))
  assert.eq(resolve("corrected"), ("384", "corrected", false, false, false))
  assert.eq(resolve("prepayment"), ("386", "prepayment", false, false, false))
  assert.eq(resolve("self-billed"), ("389", "self-billed", false, true, true))
  // A code is the named type of the same code
  assert.eq(resolve-document-type("381").name, "credit-note")
  assert.eq(resolve-document-type(381).code, "381")
  // Other codes of UNTDID 1001 take the title of their kind
  assert.eq(resolve("326"), ("326", "invoice", false, false, false))
  assert.eq(resolve("875"), ("875", "invoice", false, false, false))
  assert.eq(resolve("396"), ("396", "credit-note", true, false, true))
  // A self-billed credit note: the buyer issues it, the seller pays back
  assert.eq(resolve("261"), ("261", "credit-note", true, true, false))
  assert.eq(resolve-document-type(auto).input, auto)
  assert.eq(resolve-document-type("invoice").input, "invoice")
  assert(not sender-pays(none))
}

// --- 2. The kind of document a title names ---
#{
  let kind(title) = {
    let named = title-kind(title)
    if named == none { none } else { named.kind }
  }
  assert.eq(kind("Rechnung"), "invoice")
  assert.eq(kind("Gutschrift"), "credit-note-or-self-billed")
  assert.eq(kind("GUTSCHRIFT Nr. 17"), "credit-note-or-self-billed")
  assert.eq(kind("Rechnungskorrektur"), "credit-note")
  assert.eq(kind("Credit Note"), "credit-note")
  assert.eq(kind("Credit invoice 17"), "credit-note")
  assert.eq(kind("Facture d’avoir"), "credit-note")
  assert.eq(kind("Nota di credito"), "credit-note")
  assert.eq(kind("Korrigierte Rechnung"), "corrected")
  assert.eq(kind("Facturación por el destinatario"), "self-billed")
  assert.eq(kind("Self-Billing Invoice"), "self-billed")
  assert.eq(kind("Angebot"), "quote")
  assert.eq(kind("Kostenvoranschlag: Dachsanierung"), "quote")
  assert.eq(kind("Devis n°12"), "quote")
  assert.eq(kind("Proforma-Rechnung"), "pro-forma")
  assert.eq(kind("Facture pro forma"), "pro-forma")
  assert.eq(kind("Lieferschein"), "delivery-note")
  assert.eq(kind("Auftragsbestätigung"), "order")
  assert.eq(kind("Zahlungserinnerung"), "reminder")
  // The first word that names a kind of document decides
  assert.eq(kind("Rechnung zum Angebot 2026-5"), "invoice")
  assert.eq(kind("Invoice for quote Q-17"), "invoice")
  assert.eq(kind("Angebot zur Rechnung 17"), "quote")
  // Words that contain a keyword are no keyword
  assert.eq(kind("Angebotsnummer 5"), none)
  assert.eq(kind("Wartungsvertrag"), none)
  assert.eq(kind(""), none)
  // The title of an invoice in each language of the package names an
  // invoice: `invoice` passes a default subject to the e-invoice only when
  // the locale titles an invoice otherwise (`_title-to-check` in
  // src/invoice.typ).
  for (code, language) in dictionary(languages) {
    assert.eq(kind(language.document.invoice), "invoice", message: code)
  }
}

// --- 3. The printed title follows the document type ---
// A theme that hands the title to `check`.
#let title-test(check, ..args) = invoice(
  theme: () => themes.blank() + (document: (ctx, body) => check(ctx)),
  sender: seller,
  recipient: buyer-fr,
  invoice-nr: "2026-17",
  ..args,
)[]

#for (locale, type, title) in (
  (locale.de-de, auto, "Rechnung"),
  (locale.de-de, "credit-note", "Rechnungskorrektur"),
  (locale.de-de, "corrected", "Korrigierte Rechnung"),
  (locale.de-de, "prepayment", "Anzahlungsrechnung"),
  (locale.de-de, "self-billed", "Gutschrift"),
  (locale.en-de, "credit-note", "Credit Note"),
  (locale.en-de, "self-billed", "Self-Billing Invoice"),
  (locale.fr-fr, "credit-note", "Avoir"),
  (locale.fr-fr, "self-billed", "Autofacturation"),
  (locale.it-it, "credit-note", "Nota di credito"),
  (locale.es-es, "corrected", "Factura rectificativa"),
  // Codes without a title of their own are titled by their kind
  (locale.de-de, "326", "Rechnung"),
  (locale.de-de, "396", "Rechnungskorrektur"),
) {
  title-test(locale: locale, document-type: type, ctx => {
    assert.eq(ctx.subject, title + " 2026-17")
    []
  })
}

// The e-invoice gets the subject the sender gives, without the invoice
// number, to compare it with the document type (IP-DOC-01), and a default
// subject only when the locale titles an invoice otherwise than its
// language (see section 6): the title of the type cannot contradict it.
#model-test(document-type: "credit-note", model => {
  assert.eq(model.invoice.title, none)
})[
  #line-items[#item([Bonus], price: 500)]
  #payment-goal(days: 14)
  #bank
]
#model-test(document-type: "credit-note", subject: [Gutschrift], model => {
  assert.eq(model.invoice.title, "Gutschrift")
})[
  #line-items[#item([Bonus], price: 500)]
  #payment-goal(days: 14)
  #bank
]
#model-test(model => {
  assert.eq(model.invoice.title, none)
  assert.eq(model.invoice.type-code, "380")
})[
  #line-items[#item([Bonus], price: 500)]
  #payment-goal(days: 14)
  #bank
]

// An explicit subject is kept, whatever the document type
#title-test(
  locale: locale.de-de,
  document-type: "credit-note",
  subject: "Gutschrift",
  ctx => {
    assert.eq(ctx.subject, "Gutschrift 2026-17")
    []
  },
)

// --- 4. The payment goal and the bank details of a credit note ---
// On a credit note, the sender pays the amount to the recipient: the payment
// sentence says so, the bank details are the recipient's account (the
// default account holder), and there is no EPC-QR code for the recipient to
// scan.
#let payment-theme(check-goal, check-bank) = () => (
  themes.blank()
    + (
      payment-goal: (ctx, view) => {
        check-goal(plain-text((themes.blank().payment-goal)(ctx, view)))
        []
      },
      bank-details: (ctx, view) => {
        check-bank(view)
        []
      },
    )
)

#invoice(
  theme: payment-theme(
    sentence => {
      assert(sentence.starts-with("Den Betrag in Höhe von 595,00"))
      assert(
        sentence.ends-with(
          " überweisen wir innerhalb von 14 Tagen auf das unten angegebene Konto.",
        ),
      )
    },
    view => {
      assert.eq(view.sender.name, "Buyer GmbH")
      assert.eq(view.qr-code.display, false)
      assert.eq(view.qr-code.payload, none)
    },
  ),
  locale: locale.de-de,
  document-type: "credit-note",
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "RK-1",
  date: datetime(year: 2026, month: 9, day: 1),
)[
  #line-items[#item([Bonus], price: 500, tax: tax.vat(19%))]
  #payment-goal(days: 14)
  #bank-details(iban: "DE75512108001245126199")
]

// ... paid at once, and in English
#invoice(
  theme: payment-theme(
    sentence => {
      assert(sentence.starts-with("We will transfer the amount of 595,00"))
      assert(sentence.ends-with(" promptly to the account listed below."))
    },
    view => assert.eq(view.sender.name, "Buyer GmbH"),
  ),
  locale: locale.en-de,
  document-type: "credit-note",
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "RK-2",
)[
  #line-items[#item([Bonus], price: 500, tax: tax.vat(19%))]
  #payment-goal()
  #bank-details(iban: "DE75512108001245126199")
]

// The e-invoice states the payment terms the payment goal prints (BT-20):
// on a credit note or a self-billed invoice paid at once, that the sender
// transfers the amount promptly, not that it is due on receipt
#let paid-at-once = [
  #line-items[#item([Bonus], price: 500, tax: tax.vat(19%))]
  #payment-goal()
  #bank
]
#model-test(document-type: "credit-note", model => {
  assert.eq(model.payment.terms, "umgehend")
  assert.eq(xml-values(model, "ram:Description"), ("umgehend",))
})[#paid-at-once]
#model-test(
  locale: locale.en-de,
  document-type: "self-billed",
  sender: buyer-fr,
  recipient: seller,
  model => assert.eq(model.payment.terms, "promptly"),
)[#paid-at-once]
#model-test(model => {
  assert.eq(model.payment.terms, "sofort nach Erhalt")
})[#paid-at-once]

// An invoice keeps its sentence, the sender as account holder and the
// EPC-QR code; an explicit holder or QR setting is kept on a credit note.
#invoice(
  theme: payment-theme(
    sentence => assert(sentence.starts-with("Bitte überweisen Sie")),
    view => {
      assert.eq(view.sender.name, "Seller GmbH")
      assert.eq(view.qr-code.display, true)
      assert.ne(view.qr-code.payload, none)
    },
  ),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "R-1",
)[
  #line-items[#item([Beratung], price: 500, tax: tax.vat(19%))]
  #payment-goal(days: 14)
  #bank-details(iban: "DE75512108001245126199")
]
#invoice(
  theme: payment-theme(
    _ => none,
    view => {
      assert.eq(view.sender.name, "Kontoinhaber")
      assert.eq(view.qr-code.display, true)
    },
  ),
  locale: locale.de-de,
  document-type: "credit-note",
  sender: seller,
  recipient: buyer-de,
  invoice-nr: "RK-3",
)[
  #line-items[#item([Bonus], price: 500, tax: tax.vat(19%))]
  #bank-details(
    name: "Kontoinhaber",
    iban: "DE75512108001245126199",
    qr-code: (display: true),
  )
]

// The sender of a credit note or a self-billed invoice pays the amount: it
// cannot collect it from the recipient by direct debit or payment card, and
// grants no cash discount. Each stops with a message instead of printing a
// sentence in the wrong direction.
#for (document-type, sender, recipient) in (
  ("credit-note", seller, buyer-de),
  ("self-billed", buyer-de, seller),
) {
  let message(body) = catch(() => invoice(
    theme: themes.blank,
    locale: locale.de-de,
    document-type: document-type,
    sender: sender,
    recipient: recipient,
    invoice-nr: "RK-4",
  )[
    #line-items[#item([Bonus], price: 500, tax: tax.vat(19%))]
    #body
  ])
  for (body, expected) in (
    (
      direct-debit(mandate: "M-1", creditor-id: "DE98ZZZ09999999999"),
      "direct-debit: a credit note or a self-billed invoice is paid by its sender",
    ),
    (
      card-payment(last4: "1234"),
      "card-payment: a credit note or a self-billed invoice is paid by its sender",
    ),
    (
      payment-goal(days: 30, discount: (days: 14, percent: 2%)),
      "payment-goal: a cash discount (`discount`) is not supported on a credit note or a self-billed invoice",
    ),
  ) {
    let got = message(body)
    assert(
      got != none and got.contains(expected),
      message: "Expected `" + expected + "`, got " + repr(got),
    )
  }
}

// --- 5. The document type is written as BT-3 ---
#for (type, code) in (
  (auto, "380"),
  ("credit-note", "381"),
  ("corrected", "384"),
  ("prepayment", "386"),
  ("self-billed", "389"),
  ("875", "875"),
) {
  model-test(document-type: type, preceding-invoice-nr: "R-1", model => {
    assert.eq(model.invoice.type-code, code)
    assert.eq(xml-values(model, "ram:TypeCode").first(), code)
    assert.eq(rules(model), ())
  })[
    #line-items[#item([Consulting], price: 1000)]
    #payment-goal(days: 14)
    #bank
  ]
}

// --- 6. A subject that names another kind of document (IP-DOC-01) ---
#model-test(subject: "Gutschrift", model => {
  assert.eq(rules(model), ("IP-DOC-01",))
  let d = diagnostic(model, "IP-DOC-01")
  assert.eq(d.field, "subject")
  assert.eq(
    d.message,
    "The subject \"Gutschrift\" names a credit note or a self-billed invoice, but the e-invoice states a commercial invoice (BT-3 = 380), which asks the buyer to pay.",
  )
  assert(d.hint.contains("`document-type: \"credit-note\"`"))
  assert(d.hint.contains("`document-type: \"self-billed\"`"))
  assert(d.hint.contains("`document-type: \"invoice\"`"))

  // An explicit document type settles it, also as an invoice
  let m = model
  m.invoice.document = resolve-document-type("invoice")
  assert.eq(rules(m), ())
  m.invoice.document = resolve-document-type("credit-note")
  assert.eq(rules(m), ())

  // Quotes and the like are no invoice
  m.invoice.document = resolve-document-type(auto)
  m.invoice.title = "Angebot"
  let d = diagnostic(m, "IP-DOC-01")
  assert.eq(
    d.message,
    "The subject \"Angebot\" names a quote, which is no invoice, but the e-invoice states a commercial invoice (BT-3 = 380).",
  )
  assert(d.hint.starts-with("Do not set `zugferd` for quotes"))
  m.invoice.title = "Korrigierte Rechnung"
  assert(
    diagnostic(m, "IP-DOC-01").hint.contains("`document-type: \"corrected\"`"),
  )
  // "Rechnungskorrektur" names a credit note or a corrected invoice
  m.invoice.title = "Rechnungskorrektur"
  let hint = diagnostic(m, "IP-DOC-01").hint
  assert(hint.contains("`document-type: \"credit-note\"` (381)"))
  assert(hint.contains("`document-type: \"corrected\"` (384)"))
  assert(not hint.contains("self-billed"))
  m.invoice.title = "Rechnung zum Angebot 2026-5"
  assert.eq(rules(m), ())
})[
  #line-items[#item([Bonus], price: 500)]
  #payment-goal(days: 14)
  #bank
]

// The default title of the locale is checked as well (a pro forma invoice
// is no invoice)
#model-test(
  locale: locale.de-de.with(locale.custom.document(invoice: "Proforma")),
  model => assert.eq(rules(model), ("IP-DOC-01",)),
)[
  #line-items[#item([Muster], price: 500)]
  #payment-goal(days: 14)
  #bank
]

// --- 7. XRechnung allows eight document types (BR-DE-17) ---
#model-test(
  zugferd: "xrechnung",
  recipient: buyer-de,
  document-type: "prepayment",
  model => {
    assert.eq(rules(model), ("BR-DE-17",))
    let d = diagnostic(model, "BR-DE-17")
    assert.eq(d.field, "document-type")
    assert(d.hint.contains("no prepayment invoice"))
  },
)[
  #line-items[#item([Anzahlung Projekt], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// With `zugferd: auto`, the prepayment invoice is written as EN 16931
#{
  let theme = () => (
    themes.blank()
      + (
        zugferd-report: (ctx, result) => {
          assert.eq(result.profile.id, "en16931")
          assert.eq(
            result.diagnostics.map(d => (d.level, d.rule)),
            (("warning", "BR-DE-17"),),
          )
          []
        },
      )
  )
  invoice(
    theme: theme,
    locale: locale.de-de,
    zugferd: auto,
    zugferd-errors: "report",
    document-type: "prepayment",
    sender: seller,
    recipient: buyer-de,
    invoice-nr: "AZ-1",
    date: datetime(year: 2026, month: 9, day: 1),
  )[
    #line-items[#item([Anzahlung Projekt], price: 1000)]
    #payment-goal(days: 14)
    #bank
  ]
}

// --- 8. The sign of the amounts ---
// A credit note states the credited amounts as positive amounts
#model-test(document-type: "credit-note", model => {
  assert.eq(rules(model), ("IP-DOC-03",))
  assert.eq(
    diagnostic(model, "IP-DOC-03").message,
    "A credit note (BT-3 = 381) states the credited amounts as positive amounts, but its total is -595.00, which would ask the buyer to pay 595.00.",
  )
})[
  #line-items[#item([Bonus], price: -500, tax: tax.vat(19%))]
  #bank
]
// An invoice with a negative total is valid, but most likely a credit note
#model-test(model => {
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ("IP-DOC-04",))
})[
  #line-items[#item([Bonus], price: -500, tax: tax.vat(19%))]
  #bank
]

// --- 9. A self-billed invoice: the sender is the buyer ---
#let process(ctx, data) = {
  let signal(kind) = loom.query.find-signal(data, kind)
  process-zugferd(
    ctx,
    signal("line-items").item-data,
    payment-goal: signal("payment-goal"),
    bank: signal("bank-details"),
  )
}

#model-test(
  document-type: "self-billed",
  sender: buyer-fr,
  recipient: seller,
  model => {
    assert.eq(model.seller.name, "Seller GmbH")
    assert.eq(model.seller.vat-id, "DE123456789")
    assert.eq(model.seller.tax-nr, "123/456/78901")
    assert.eq(model.buyer.name, "Buyer SAS")
    assert.eq(model.buyer.vat-id, "FR99123456789")
    assert.eq(xml-values(model, "ram:TypeCode").first(), "389")
    assert.eq(rules(model), ())
  },
)[
  #line-items[#item([Provision], price: 1000, tax: tax.vat(19%))]
  #payment-goal(days: 14)
  #bank
]

// The delivery address `invoice` adds to the recipient is the buyer's
// delivery (BG-13), not an input of the seller the recipient of a
// self-billed invoice is: no IP-KEY-01
#model-test(
  document-type: "self-billed",
  sender: buyer-de,
  recipient: seller,
  delivery-address: (
    name: "Buyer GmbH, Lager",
    address: "Lagerweg 1",
    city: "50667 Köln",
  ),
  model => {
    assert.eq(model.ship-to.address.city, "Köln")
    assert("IP-KEY-01" not in rules(model, level: "warning"))
  },
)[#paid-at-once]

// The diagnostics name the inputs: the seller's are the recipient's
#invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
  zugferd-errors: "ignore",
  document-type: "self-billed",
  sender: buyer-de,
  recipient: seller + (contact: none),
  invoice-nr: "GS-1",
  date: datetime(year: 2026, month: 9, day: 1),
  data-test(test: (ctx, data) => {
    let result = process(ctx, data)
    assert.eq(result.model.seller.name, "Seller GmbH")
    let errors = result.diagnostics.filter(d => d.level == "error")
    assert.eq(errors.map(d => (d.rule, d.field)), (
      ("BR-DE-2", "recipient.contact"),
    ))
    assert.eq(
      errors.first().hint,
      "Set `contact: (name: .., phone: .., email: ..)` on the recipient.",
    )
  })[
    #line-items[#item([Provision], price: 1000, tax: tax.vat(19%))]
    #payment-goal(days: 14)
    #bank
  ],
)

// The references of a self-billed invoice state the seller's (recipient's)
// tax number and VAT ID, and the buyer's (sender's) VAT ID, followed by the
// date of the supply, which the seller in Germany must state (§ 14 Abs. 4
// Satz 1 Nr. 6 UStG)
#title-test(
  locale: locale.de-de,
  document-type: "self-billed",
  sender: buyer-de,
  recipient: seller,
  ctx => {
    assert.eq(ctx.references.slice(0, 3), (
      ("Empfänger:in Steuernummer", "123/456/78901"),
      ("Empfänger:in USt-IdNr.", "DE123456789"),
      ("USt-IdNr.", "DE987654321"),
    ))
    assert.eq(ctx.references.map(r => r.first()).slice(3), (
      "Leistungszeitraum",
    ))
    []
  },
)
