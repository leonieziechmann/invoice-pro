// A payee (BG-10), e.g. a factoring company that receives the payment
// instead of the seller, is printed as the e-invoice states it: in the
// default references, and as the account holder of the bank details and the
// beneficiary of the EPC-QR code, unless `bank-details` names another one.
// The account name of the e-invoice (BT-85) stays an explicit `name` only.

#import "/src/lib.typ": *
#import "/src/utils/text.typ": plain-text
#import "/tests/zugferd/harness.typ": (
  buyer-fr, model-test, rules, seller, xml-elements, xml-values,
)

#let payee = (name: "Factoring Bank AG", id: id.gln("4000001543212"))
#let iban = "DE89370400440532013000"

// Records the references and the bank details view.
#let capturing-theme = themes.blank.with(
  document: (ctx, body) => {
    [#metadata(ctx.references.map(((label, value)) => (
      label,
      plain-text(value),
    )))<references>]
    body
  },
  bank-details: (ctx, view) => [#metadata(view)<bank-details>],
)

#let test-invoice(..bank, payee: payee, document-type: auto) = invoice(
  theme: capturing-theme,
  locale: locale.de-de,
  sender: seller,
  recipient: buyer-fr,
  payee: payee,
  document-type: document-type,
  invoice-nr: "RE-2026-7",
  date: datetime(year: 2026, month: 9, day: 1),
)[
  #line-items[#item([Beratung], price: 100, tax: tax.vat(19%))]
  #payment-goal(days: 14)
  #bank-details(bank: "Factoring Bank", iban: iban, ..bank)
]

#test-invoice()
#test-invoice(name: "Treuhandkonto Muster GmbH")
#test-invoice(payee: none)

#context {
  let references = query(<references>).map(it => it.value)
  let views = query(<bank-details>).map(it => it.value)
  assert.eq(views.len(), 3)
  let (default, named, without) = views

  // The default references name the payee
  assert(
    ("Zahlungsempfänger", "Factoring Bank AG") in references.first(),
    message: repr(references.first()),
  )
  assert(references.last().all(((label, _)) => label != "Zahlungsempfänger"))

  // The payee is the default account holder and the beneficiary of the
  // EPC-QR code
  assert.eq(default.sender.name, "Factoring Bank AG")
  assert.eq(default.qr-code.payload.beneficiary, "Factoring Bank AG")
  // ... unless the bank details name the account holder
  assert.eq(named.sender.name, "Treuhandkonto Muster GmbH")
  assert.eq(named.qr-code.payload.beneficiary, "Treuhandkonto Muster GmbH")
  // Without a payee, the seller
  assert.eq(without.sender.name, "Seller GmbH")
}

// The e-invoice names the payee (BG-10) and states an account name (BT-85)
// only when `bank-details` gives one
#model-test(payee: payee, model => {
  assert.eq(rules(model), ())
  assert.eq(xml-values(model, "ram:AccountName"), ())
  assert(
    xml-elements(model, "ram:PayeeTradeParty")
      .first()
      .contains("<ram:Name>Factoring Bank AG</ram:Name>"),
  )
})[
  #line-items[#item([Beratung], price: 100, tax: tax.vat(19%))]
  #payment-goal(days: 14)
  #bank-details(bank: "Factoring Bank", iban: iban)
]
