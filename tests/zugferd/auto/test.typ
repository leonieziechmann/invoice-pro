// `zugferd: auto` chooses the richest profile the invoice satisfies:
// XRechnung for a buyer in Germany, otherwise EN 16931. The errors that ruled
// out XRechnung are listed as warnings of the chosen profile.

#import "/src/lib.typ": *
#import "/src/zugferd/zugferd.typ": process-zugferd
#import "/tests/data-test.typ": data-test, loom

#let seller = (
  name: "Seller GmbH",
  address: "Street 1",
  city: (name: "München", post-code: "80339"),
  country: country.de,
  vat-id: "DE123456789",
  contact: (
    name: "Max Mustermann",
    phone: "+49 89 123456",
    email: "seller@example.de",
  ),
)

#let buyer = (
  name: "Buyer GmbH",
  address: "Weg 5",
  city: (name: "Berlin", post-code: "10115"),
  country: country.de,
  email: "buyer@example.de",
  buyer-reference: "04011000-12345-67",
)

#let rules(result, level) = (
  result.diagnostics.filter(d => d.level == level).map(d => d.rule).sorted()
)

// Runs `test` on the e-invoice result of an invoice with the given data.
#let auto-test(
  zugferd: auto,
  recipient: buyer,
  with-goal: true,
  test,
) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: zugferd,
  zugferd-errors: "ignore",
  sender: seller,
  recipient: recipient,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  data-test(test: (ctx, data) => {
    let signal(kind) = loom.query.find-signal(data, kind)
    test(process-zugferd(
      ctx,
      signal("line-items").item-data,
      payment-goal: signal("payment-goal"),
      bank: signal("bank-details"),
    ))
  })[
    #line-items[#item([Consulting], price: 100, tax: tax.vat(19%))]
    #if with-goal [#payment-goal(days: 14)]
    #bank-details(
      bank: "Musterbank",
      iban: "DE89370400440532013000",
      bic: "COBADEFFXXX",
    )
  ],
)

// 1. A complete invoice to a buyer in Germany is written as XRechnung
#auto-test(result => {
  assert.eq(result.profile.id, "xrechnung")
  assert.eq(result.profile.skipped, ())
  assert.eq(rules(result, "error"), ())
  assert(str(result.xml).contains("urn:xeinkauf.de:kosit:xrechnung_3.0"))
})

// 2. Without the buyer reference (BT-10) XRechnung is not possible: the XML is
//    EN 16931 and the missing reference is a warning
#auto-test(recipient: buyer + (buyer-reference: none), result => {
  assert.eq(result.profile.id, "en16931")
  assert.eq(result.profile.skipped, ((id: "xrechnung", name: "XRechnung 3.0"),))
  assert.eq(rules(result, "error"), ())
  assert.eq(rules(result, "warning"), ("BR-DE-15",))
  assert(
    result
      .diagnostics
      .first()
      .message
      .starts-with("Needed for XRechnung 3.0: "),
  )
  assert(not str(result.xml).contains("xrechnung"))
})

// 3. A buyer outside Germany gets EN 16931 without trying XRechnung
#auto-test(
  recipient: buyer
    + (country: country.fr, city: "75002 Paris", vat-id: "FR40303265045"),
  result => {
    assert.eq(result.profile.id, "en16931")
    assert.eq(result.profile.candidates, ("en16931",))
    assert.eq(result.profile.skipped, ())
    assert.eq(rules(result, "error"), ())
  },
)

// 4. Errors of EN 16931 stay errors; a rule both profiles violate is not
//    repeated as a warning
#auto-test(
  recipient: buyer + (buyer-reference: none),
  with-goal: false,
  result => {
    assert.eq(result.profile.id, "en16931")
    assert.eq(rules(result, "error"), ("BR-CO-25",))
    assert.eq(rules(result, "warning"), ("BR-DE-15",))
  },
)

// 5. An explicit profile is used as given, also between German parties
#auto-test(
  zugferd: "en16931",
  recipient: buyer + (buyer-reference: none),
  result => {
    assert.eq(
      (result.profile.id, result.profile.automatic, result.profile.skipped),
      ("en16931", false, ()),
    )
    assert.eq(result.diagnostics, ())
  },
)
