// The payment means of an e-invoice (BG-16) besides the bank details: a SEPA
// direct debit (BG-19), a payment card (BG-18) and an invoice that is paid
// already (BT-113, BT-115), the account name of a credit transfer (BT-85),
// and the rules that keep them consistent: one kind of payment means per
// invoice, and the XRechnung rules BR-DE-1, BR-DE-19, BR-DE-20, BR-DE-23 to
// BR-DE-25, BR-DE-30, BR-DE-31 and PEPPOL-EN16931-R061.

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/build.typ": build-xml
#import "/src/zugferd/rules/engine.typ": run-rules
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, diagnostic, model-test, rules, xml-elements, xml-values,
)

#let xrechnung = (zugferd: "xrechnung", recipient: buyer-de)
#let en16931 = resolve-profile("en16931", "FR")
#let debit = direct-debit(
  mandate: "M-2026-017",
  creditor-id: "de98 zzz0 9999 9999 99",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
#let card = card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")
#let items = line-items[
  #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
]
#let goal = payment-goal(days: 14)

// A payment means of the model without details.
#let means(type-code, kind, field, ..details) = (
  (
    type-code: type-code,
    kind: kind,
    field: field,
    iban: none,
    account-name: none,
    bic: none,
    card: none,
    debtor-iban: none,
  )
    + details.named()
)

// --- 1. A SEPA direct debit states the mandate reference (BT-89), the
// creditor identifier (BT-90) and the debited account (BT-91) ---
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, (
    means(
      "59",
      "direct-debit",
      "direct-debit",
      debtor-iban: "DE02120300000000202051",
    ),
  ))
  assert.eq(model.payment.mandate, "M-2026-017")
  assert.eq(model.payment.creditor-id, "DE98ZZZ09999999999")
  assert.eq(model.payment.paid, false)
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ())

  // BT-90 is the first element of the settlement, BT-89 part of the terms
  let xml = build-xml(model)
  assert(
    xml.contains(
      "<ram:ApplicableHeaderTradeSettlement><ram:CreditorReferenceID>DE98ZZZ09999999999</ram:CreditorReferenceID><ram:PaymentReference>",
    ),
  )
  assert.eq(xml-elements(model, "ram:SpecifiedTradeSettlementPaymentMeans"), (
    "<ram:SpecifiedTradeSettlementPaymentMeans><ram:TypeCode>59</ram:TypeCode><ram:PayerPartyDebtorFinancialAccount><ram:IBANID>DE02120300000000202051</ram:IBANID></ram:PayerPartyDebtorFinancialAccount></ram:SpecifiedTradeSettlementPaymentMeans>",
  ))
  assert.eq(xml-values(model, "ram:DirectDebitMandateID"), ("M-2026-017",))

  // The parts XRechnung requires (BR-DE-30, BR-DE-31, PEPPOL-EN16931-R061),
  // which EN 16931 leaves open
  let m = model
  m.payment.mandate = none
  assert.eq(rules(m), ("PEPPOL-EN16931-R061",))
  m.profile = en16931
  assert.eq(rules(m), ())
  let m = model
  m.payment.creditor-id = none
  assert.eq(rules(m), ("BR-DE-30",))
  let m = model
  m.payment.means.at(0).debtor-iban = none
  assert.eq(rules(m), ("BR-DE-31",))
  assert.eq(diagnostic(m, "BR-DE-31").field, "direct-debit.debtor-iban")
  m.profile = en16931
  assert.eq(rules(m), ())

  // Identifiers with wrong check digits, for `zugferd-errors: "report"`
  let m = model
  m.payment.means.at(0).debtor-iban = "DE00120300000000202051"
  assert.eq(rules(m), ("BR-DE-20",))
  m.profile = en16931
  assert.eq(rules(m), ("IP-PAY-01",))
  let m = model
  m.payment.creditor-id = "DE00ZZZ09999999999"
  assert.eq(rules(m), ("IP-PAY-02",))
  assert.eq(diagnostic(m, "IP-PAY-02").field, "direct-debit.creditor-id")
})[#items #goal #debit]

// Without the debited account: XRechnung requires it (BR-DE-31)
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means.first().debtor-iban, none)
  assert.eq(rules(model), ("BR-DE-31",))
})[
  #items
  #goal
  #direct-debit(mandate: "M-1", creditor-id: "DE98ZZZ09999999999")
]

// Outside the euro area, a direct debit is no SEPA direct debit (49), and the
// creditor identifier follows no SEPA format
#model-test(locale: locale.de-ch, model => {
  assert.eq(model.payment.means.first().type-code, "49")
  assert.eq(model.payment.creditor-id, "CH12ZZZ12345")
  assert.eq(rules(model), ())
})[
  #items
  #goal
  #direct-debit(
    mandate: "M-1",
    creditor-id: "CH12ZZZ12345",
    debtor-iban: "CH9300762011623852957",
  )
]

// --- 2. A payment card states the last digits of the card number (BT-87)
// and the card holder (BT-88) ---
#model-test(model => {
  assert.eq(model.payment.means, (
    means(
      "54",
      "card",
      "card-payment",
      card: (id: "1234", holder: "Erika Kunde"),
    ),
  ))
  assert.eq(rules(model), ())
  assert.eq(xml-elements(model, "ram:SpecifiedTradeSettlementPaymentMeans"), (
    "<ram:SpecifiedTradeSettlementPaymentMeans><ram:TypeCode>54</ram:TypeCode><ram:ApplicableTradeSettlementFinancialCard><ram:ID>1234</ram:ID><ram:CardholderName>Erika Kunde</ram:CardholderName></ram:ApplicableTradeSettlementFinancialCard></ram:SpecifiedTradeSettlementPaymentMeans>",
  ))
})[#items #goal #card]

// A debit card (55), a card of either kind (48) without holder
#model-test(model => {
  assert.eq(model.payment.means.first().type-code, "55")
})[#items #goal #card-payment(last4: "987654", kind: "debit")]
#model-test(model => {
  assert.eq(model.payment.means.first().type-code, "48")
  assert.eq(model.payment.means.first().card, (id: "4321", holder: none))
})[#items #goal #card-payment(last4: "43 21")]

// BASIC has no payment card: only the payment means code is written
#model-test(zugferd: "basic", model => {
  assert.eq(xml-elements(model, "ram:SpecifiedTradeSettlementPaymentMeans"), (
    "<ram:SpecifiedTradeSettlementPaymentMeans><ram:TypeCode>54</ram:TypeCode></ram:SpecifiedTradeSettlementPaymentMeans>",
  ))
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ("IP-PROFILE-01",))
  assert.eq(diagnostic(model, "IP-PROFILE-01").field, "card-payment")
})[#items #goal #card]

// --- 3. A paid invoice: the paid amount is the total, nothing is due ---
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, (means("10", "other", "paid"),))
  assert.eq(model.payment.paid, true)
  assert.eq(model.totals.prepaid, model.totals.gross)
  assert.eq(model.totals.due, decimal("0"))
  // The payment terms (BT-20) are the printed sentence and method
  assert.eq(
    model.payment.terms,
    "Der Gesamtbetrag in Höhe von 238,00 € wurde am 01.09.2026 bezahlt.\nZahlungsart: Barzahlung",
  )
  assert.eq(model.payment.terms-input, "paid")
  assert.eq(rules(model), ())
  assert.eq(xml-values(model, "ram:TotalPrepaidAmount"), ("238.00",))
  assert.eq(xml-values(model, "ram:DuePayableAmount"), ("0.00",))
})[
  #items
  #paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
]

// Paid after prepayments: the rest of the amount due is paid
#model-test(..xrechnung, model => {
  assert.eq(model.totals.prepaid, model.totals.gross)
  assert.eq(model.totals.due, decimal("0"))
  assert.eq(
    model.payment.terms,
    "Der fällige Betrag in Höhe von 138,00 € wurde bezahlt.\nZahlungsart: Online-Zahlung",
  )
  assert.eq(model.payment.means.first().type-code, "68")
  assert.eq(rules(model), ())
})[
  #line-items[
    #item([Consulting], price: 100, quantity: 2, unit: unit.hour)
    #prepayment(100)
  ]
  #paid(method: "online")
]

// A method with the details of its component: the component prints the
// method, so the terms state the sentence only
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means.first().kind, "card")
  assert.eq(model.payment.means.len(), 1)
  assert.eq(
    model.payment.terms,
    "Der Gesamtbetrag in Höhe von 238,00 € wurde bezahlt.",
  )
  assert.eq(rules(model), ())
})[#items #paid(method: "card") #card]

// Without `method`, the payment means of the invoice is the one it was paid
// with; without one, EN 16931 states none, XRechnung requires it (BR-DE-1)
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means.map(m => m.type-code), ("58",))
  assert.eq(model.totals.due, decimal("0"))
  assert.eq(rules(model), ())
})[#items #paid() #bank]
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, ())
  assert.eq(rules(model), ("BR-DE-1",))
  let d = diagnostic(model, "BR-DE-1")
  assert.eq(d.field, "paid.method")
  assert(d.hint.contains("`paid(method: \"cash\")`"), message: d.hint)
  let m = model
  m.profile = en16931
  assert.eq(rules(m), ())
})[#items #paid()]

// A method whose details are missing: EN 16931 states the payment means code
// alone, XRechnung requires the details (BR-DE-23-a, BR-DE-24-a,
// BR-DE-25-a); a credit transfer needs the account in any profile: the CEN
// Schematron 1.3.16 checks it as CII-SR-470, and in BASIC WL and BASIC,
// whose BR-61 tests the debited account, invoice-pro as IP-PAY-04
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, (means("48", "card", "paid"),))
  assert.eq(rules(model), ("BR-DE-24-a",))
  let m = model
  m.profile = en16931
  assert.eq(rules(m), ())
})[#items #paid(method: "card")]
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, (means("58", "transfer", "paid"),))
  assert.eq(rules(model), ("BR-DE-23-a",))
  let d = diagnostic(model, "BR-DE-23-a")
  assert.eq(d.field, "paid.method")
  assert(d.hint.contains("`#bank-details(iban: ..)`"), message: d.hint)
  let m = model
  m.profile = en16931
  assert.eq(rules(m), ("CII-SR-470",))
  for id in ("basic-wl", "basic") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(rules(m), ("IP-PAY-04",))
    assert.eq(diagnostic(m, "IP-PAY-04").field, "paid.method")
  }
})[#items #paid(method: "transfer")]
// Bank details without an IBAN (only with `zugferd-errors: "report"`, which
// `bank-details` does not stop) ask for the IBAN
#model-test(..xrechnung, model => {
  let m = model
  m.payment.means.at(0).iban = none
  assert.eq(rules(m), ("BR-DE-23-a",))
  let d = diagnostic(m, "BR-DE-23-a")
  assert.eq(d.field, "bank-details.iban")
  assert.eq(d.hint, "Set `iban` on `bank-details`.")
  m.profile = en16931
  assert.eq(diagnostic(m, "CII-SR-470").field, "bank-details.iban")
})[#items #goal #bank]
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, (means("59", "direct-debit", "paid"),))
  assert.eq(rules(model), ("BR-DE-25-a",))
  let m = model
  m.profile = en16931
  assert.eq(rules(m), ())
})[#items #paid(method: "direct-debit")]
// Outside the euro area, XRechnung requires the mandate reference of any
// direct debit (49, PEPPOL-EN16931-R061)
#model-test(..xrechnung, locale: locale.de-ch, model => {
  assert.eq(model.payment.means, (means("49", "direct-debit", "paid"),))
  assert.eq(rules(model), ("PEPPOL-EN16931-R061",))
  assert.eq(diagnostic(model, "PEPPOL-EN16931-R061").field, "paid.method")
  let m = model
  m.profile = en16931
  assert.eq(rules(m), ())
})[
  #line-items[#item([Consulting], price: 100, tax: tax.vat(19%))]
  #paid(method: "direct-debit")
]

// Another payment means code of UNTDID 4461, with its printed name
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means, (means("97", "other", "paid"),))
  assert(model.payment.terms.ends-with("Zahlungsart: Verrechnung"))
  assert.eq(rules(model), ())
  let m = model
  m.payment.means.at(0).type-code = "99"
  assert.eq(rules(m), ("BR-CL-16",))
})[#items #paid(method: (code: "97", name: [Verrechnung]))]

// A credit note is paid by its sender: the terms state that the amount was
// paid to the recipient
#model-test(..xrechnung, document-type: "credit-note", model => {
  assert.eq(
    model.payment.terms,
    "Den Betrag in Höhe von 238,00 € haben wir Ihnen am 01.09.2026 ausgezahlt.\nZahlungsart: Barzahlung",
  )
  assert.eq(model.payment.terms-input, "paid")
})[
  #items
  #paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
]

// A payment means code of its own that its component states as well: the
// code is stated once, with the details of the component, and the terms
// state its name
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means.map(m => m.type-code), ("54",))
  assert.eq(model.payment.means.first().card.id, "1234")
  assert(model.payment.terms.ends-with("Zahlungsart: Visa"))
  assert.eq(rules(model), ())
})[#items #paid(method: (code: "54", name: [Visa])) #card]

// --- 4. One kind of payment means per invoice (BT-81) ---
#model-test(..xrechnung, model => {
  // Both are written, as stated, and reported
  assert.eq(model.payment.means.map(m => m.type-code), ("58", "59"))
  assert.eq(rules(model), ("BR-DE-23-b",))
  let d = diagnostic(model, "BR-DE-23-b")
  assert.eq(d.field, "bank-details, direct-debit")
  assert(
    d.message.starts-with(
      "The invoice states several payment means: a credit transfer (`bank-details`) and a direct debit (`direct-debit`).",
    ),
    message: d.message,
  )
  let m = model
  m.profile = en16931
  assert.eq(rules(m), ("IP-PAY-03",))
})[#items #goal #debit #bank]
#model-test(..xrechnung, model => {
  assert.eq(rules(model), ("BR-DE-24-b",))
})[#items #goal #debit #card]
// BR-DE-23-b and BR-DE-24-b concern the details of a direct debit (BG-19):
// `paid(method: "direct-debit")` without them is a direct debit without
// details (BR-DE-25-a) next to the credit transfer
#model-test(..xrechnung, model => {
  assert.eq(model.payment.means.map(m => m.type-code), ("58", "59"))
  assert.eq(rules(model), ("BR-DE-25-a", "IP-PAY-03"))
  assert.eq(diagnostic(model, "IP-PAY-03").field, "bank-details, paid")
})[#items #paid(method: "direct-debit") #bank]
#model-test(..xrechnung, model => {
  assert.eq(rules(model), ("IP-PAY-03",))
})[#items #goal #card #bank]
#model-test(..xrechnung, model => {
  assert.eq(rules(model), ("IP-PAY-03",))
  let d = diagnostic(model, "IP-PAY-03")
  assert.eq(d.field, "bank-details, paid")
  assert(d.message.contains("and cash (`paid`)"), message: d.message)
  assert(d.hint.contains("set `method` on `paid`"), message: d.hint)
})[#items #paid(method: "cash") #bank]

// Several accounts of a credit transfer (BG-17) are one kind
#model-test(..xrechnung, model => {
  assert.eq(
    model.payment.means.map(m => m.iban),
    ("DE75512108001245126199", "DE89370400440532013000"),
  )
  assert.eq(
    xml-elements(model, "ram:SpecifiedTradeSettlementPaymentMeans").len(),
    2,
  )
  assert.eq(rules(model), ())
})[
  #items
  #goal
  #bank
  #bank-details(bank: "Zweitbank", iban: "DE89370400440532013000")
]

// Without payment means, XRechnung lists all of them (BR-DE-1)
#model-test(..xrechnung, model => {
  assert.eq(rules(model), ("BR-DE-1",))
  let hint = diagnostic(model, "BR-DE-1").hint
  for input in (
    "#bank-details(",
    "#direct-debit(",
    "#card-payment(",
    "#paid(method: ..)",
  ) {
    assert(hint.contains(input), message: hint)
  }
})[#items #goal]

// ... but on a credit note, the sender pays the amount: the hint names the
// recipient's account, not the payment means that collect it
#model-test(
  ..xrechnung,
  document-type: "credit-note",
  preceding-invoice-nr: "2026-00",
  model => {
    assert.eq(rules(model), ("BR-DE-1",))
    let hint = diagnostic(model, "BR-DE-1").hint
    assert(hint.contains("the recipient's account"), message: hint)
    assert(hint.contains("(not your own)"), message: hint)
    assert(hint.contains("\"97\""), message: hint)
    assert(not hint.contains("#direct-debit("), message: hint)
  },
)[#items #goal]

// --- 5. The account name (BT-85): only a name given to `bank-details` ---
#model-test(model => {
  assert.eq(model.payment.means.first().account-name, "Factoring Bank AG")
  assert.eq(xml-values(model, "ram:AccountName"), ("Factoring Bank AG",))
  assert.eq(rules(model, level: "warning"), ())
})[
  #items
  #goal
  #bank-details(name: "Factoring Bank AG", iban: "DE89370400440532013000")
]
#model-test(zugferd: "basic", model => {
  assert.eq(xml-values(model, "ram:AccountName"), ())
  assert.eq(rules(model, level: "warning"), ("IP-PROFILE-01",))
  assert.eq(diagnostic(model, "IP-PROFILE-01").field, "bank-details.name")
})[
  #items
  #goal
  #bank-details(name: "Factoring Bank AG", iban: "DE89370400440532013000")
]
#model-test(model => {
  assert.eq(model.payment.means.map(m => m.account-name), (none, none))
  assert.eq(xml-values(model, "ram:AccountName"), ())
})[
  #items
  #goal
  #bank-details(iban: "DE89370400440532013000")
  #bank-details(
    name: none,
    iban: "DE75512108001245126199",
    qr-code: (display: false),
  )
]

// --- 6. MINIMUM states the amount due, but no payment means ---
#model-test(zugferd: "minimum", model => {
  assert.eq(xml-values(model, "ram:DuePayableAmount"), ("238.00",))
  assert.eq(
    xml-elements(model, "ram:SpecifiedTradeSettlementPaymentMeans"),
    (),
  )
  assert.eq(rules(model), ())
  let warnings = run-rules(model).filter(d => d.level == "warning")
  assert.eq(warnings.map(d => (d.rule, d.field)), (
    ("IP-PROFILE-01", "direct-debit"),
    ("IP-PROFILE-01", "card-payment"),
  ))
  // BASIC WL states a direct debit, but a payment card only from EN 16931 on
  assert(warnings.at(0).message.contains("the direct debit (BG-19)"))
  assert(
    warnings.at(0).hint.contains("\"basic-wl\""),
    message: warnings.at(0).hint,
  )
  assert(warnings.at(1).message.contains("the payment card (BG-18)"))
  assert(
    warnings.at(1).hint.contains("\"en16931\""),
    message: warnings.at(1).hint,
  )
})[#items #goal #debit #card]
#model-test(zugferd: "minimum", model => {
  assert.eq(xml-values(model, "ram:DuePayableAmount"), ("0.00",))
  assert.eq(rules(model), ())
  // ... nor the payment means of `paid` (IP-PROFILE-01)
  let warnings = run-rules(model).filter(d => d.level == "warning")
  assert.eq(warnings.map(d => (d.rule, d.field)), (
    ("IP-PROFILE-01", "paid.method"),
  ))
  assert.eq(
    warnings.first().message,
    "The MINIMUM profile cannot state the payment means (BT-81), so `paid.method` is not written into the e-invoice.",
  )
  assert.eq(
    warnings.first().hint,
    "Use the \"basic-wl\" profile or higher to state it.",
  )
})[#items #paid(method: "cash")]
// Without a method of its own, `paid` states none
#model-test(zugferd: "minimum", model => {
  assert.eq(rules(model, level: "warning"), ())
})[#items #paid()]
