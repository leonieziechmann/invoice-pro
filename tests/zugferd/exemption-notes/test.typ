// The VAT categories that need an exemption reason (AE, K, G, O) state the
// note of the invoice language when their items give no grounds. The VAT
// groups carry it like other grounds, so the invoice prints it below the line
// items, and the e-invoice writes the same text as exemption reason (BT-120).

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model, exemption-reason
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale
#import "/tests/zugferd/harness.typ": buyer-fr, seller

/// Renders an invoice and calls `test` with its VAT groups (as printed) and
/// the exemption reasons of its e-invoice.
#let notes-test(test, ..args, body) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "ignore",
  sender: seller,
  recipient: buyer-fr,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(
    test: (ctx, data) => {
      let item-data = loom.query.find-signal(data, "line-items").item-data
      let model = build-model(ctx, item-data)
      test(
        item-data.taxes.values(),
        model.taxes.map(tax => tax.reason),
      )
    },
    body,
  ),
)

// --- 1. The note of the language, printed and written ---
#notes-test(tax: tax.intra-community(), (taxes, reasons) => {
  let note = "Steuerfreie innergemeinschaftliche Lieferung"
  assert.eq(taxes.map(t => (t.grounds, t.grounds-list)), ((note, (note,)),))
  assert.eq(reasons, (note,))
})[#line-items[#item([Maschine], price: 1000)]]

#notes-test(
  locale: locale.en-de,
  recipient: buyer-fr + (country: country.us, vat-id: none),
  tax: tax.export(),
  (taxes, reasons) => {
    assert.eq(taxes.map(t => t.grounds-list), (("Tax-exempt export",),))
    assert.eq(reasons, ("Tax-exempt export",))
  },
)[#line-items[#item([Machine], price: 1000)]]

#notes-test(
  locale: locale.fr-fr,
  tax: tax.outside-scope(),
  (taxes, reasons) => {
    assert.eq(reasons, ("Opération non soumise à la TVA",))
  },
)[#line-items[#item([Prestation], price: 1000)]]

#notes-test(tax: tax.new(category: "AE"), (taxes, reasons) => {
  assert.eq(reasons, ("Steuerschuldnerschaft des Leistungsempfängers",))
})[#line-items[#item([Bauleistung], price: 1000)]]

// --- 2. Grounds of the items win, also those of only some of them ---
#notes-test(tax: tax.intra-community(grounds: "§ 4 Nr. 1b UStG"), (
  taxes,
  reasons,
) => {
  assert.eq(reasons, ("§ 4 Nr. 1b UStG",))
})[
  #line-items[
    #item([A], price: 1000)
    #item([B], price: 1000, tax: tax.intra-community())
  ]
]

// Taxed categories have no exemption reason
#notes-test((taxes, reasons) => {
  assert.eq(taxes.map(t => t.grounds), (none,))
  assert.eq(reasons, (none,))
})[#line-items[#item([A], price: 1000)]]

// --- 3. The small business scheme: the themes print its note themselves
// (`legal.vat-exemption` of the language, as the scheme of this locale has
// no grounds), so it is the reason of the group, but no note of its own ---
#notes-test(
  locale: test-locale,
  tax-exempt-small-biz: true,
  (taxes, reasons) => {
    let note = "No VAT is charged due to small business exemption."
    assert.eq(taxes.map(t => (t.grounds, t.grounds-list)), ((note, ()),))
    assert.eq(reasons, (note,))
  },
)[#line-items[#item([A], price: 1000)]]

// --- 4. Without a category there is no note to state ---
#{
  let strings = (tax-exemption: (outside-scope: "Nicht steuerbar"))
  assert.eq(exemption-reason("O", none, strings: strings), "Nicht steuerbar")
  assert.eq(exemption-reason(none, none, strings: strings), none)
}
