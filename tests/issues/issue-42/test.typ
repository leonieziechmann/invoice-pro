// Regression test for GitHub issue #42
// https://github.com/leonieziechmann/invoice-pro/issues/42
//
// Bug reported:
// The seller identifier (BT-29, `ram:ID`) could only be set through `tax-nr`,
// which is also written as the seller tax registration (BT-32, schemeID "FC").
// A seller without a tax number, e.g. a UK sole trader without UTR, could not
// satisfy BR-CO-26 without asserting a false tax identifier.
//
// Fix: `id` on the sender sets the seller identifier (BT-29) on its own.

#import "/src/lib.typ": *
#import "/src/zugferd/build.typ": build-seller-trade-party
#import "/src/zugferd/model.typ": build-model
#import "/src/zugferd/rules/engine.typ": run-rules
#import "/tests/data-test.typ": data-test, loom

#let sender = (
  name: "Jane Doe",
  address: "1 Example Street",
  city: "Sometown AB1 2CD",
  country: country.uk,
  contact: (
    name: "Jane Doe",
    phone: "+44 7000 000000",
    email: "jane@example.com",
  ),
)

// The seller trade party of the XML and the diagnostics of an invoice.
#let seller-test(test, ..args) = invoice(
  theme: themes.blank,
  locale: locale.en-de,
  zugferd: "en16931",
  sender: sender,
  recipient: (
    name: "Example Client GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    vat-id: "DE111111111",
    email: "contact@example.de",
  ),
  invoice-nr: "2026-00001",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(
    test: (ctx, data) => {
      let signal(kind) = loom.query.find-signal(data, kind)
      let model = build-model(
        ctx,
        signal("line-items").item-data,
        payment-goal: signal("payment-goal"),
      )
      test(
        build-seller-trade-party(model.seller, model.profile),
        run-rules(
          model,
        ),
      )
    },
  )[
    #line-items[#item([Consulting], price: 100)]
    #payment-goal(days: 14)
  ],
)

// 1. The reported invoice: the seller identifier and the tax number are set
//    separately
#seller-test(
  sender: sender + (tax-nr: "12345", id: "70025"),
  (party, diagnostics) => {
    assert.eq(party.at("ram:ID"), "70025")
    assert.eq(party.at("ram:SpecifiedTaxRegistration"), (
      ("ram:ID": ("@schemeID": "FC", "": "12345")),
    ))
    assert.eq(diagnostics, ())
  },
)

// 2. Without a tax number (not VAT registered), the identifier alone
//    identifies the seller (BR-CO-26)
#seller-test(
  sender: sender + (id: "70025"),
  tax: tax.outside-scope(grounds: "Not registered for VAT."),
  (party, diagnostics) => {
    assert.eq(party.at("ram:ID"), "70025")
    assert.eq(party.at("ram:SpecifiedTaxRegistration", default: none), none)
    assert.eq(diagnostics.filter(d => d.level == "error"), ())
  },
)

// 3. Without the identifier, the tax number still identifies the seller
#seller-test(
  sender: sender + (tax-nr: "12345"),
  (party, diagnostics) => {
    assert.eq(party.at("ram:ID"), "12345")
    assert.eq(diagnostics, ())
  },
)
