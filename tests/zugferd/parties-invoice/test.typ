// Party inputs of real invoices, from the audit of the e-invoice: what ends
// up in the XML, and what is reported instead of being written silently wrong
// or dropped.

#import "/src/lib.typ": *
#import "/src/zugferd/zugferd.typ": process-zugferd
#import "/tests/data-test.typ": data-test, loom

#let seller = (
  name: "Seller GmbH",
  address: "Street 1",
  city: "80339 München",
  country: country.de,
  tax-nr: "143/123/45678",
  vat-id: "DE123456789",
  contact: (
    name: "Max Mustermann",
    phone: "+49 89 1234567",
    email: "max@seller.de",
  ),
)

#let buyer = (
  name: "Buyer SAS",
  address: "Rue 1",
  city: "75002 Paris",
  country: country.fr,
  vat-id: "FR99123456789",
)

#let rules(result, level: "error") = (
  result.diagnostics.filter(d => d.level == level).map(d => d.rule).sorted()
)

// Runs `test` on the e-invoice result of an invoice with the given data.
#let e-invoice(
  test,
  zugferd: "en16931",
  sender: seller,
  recipient: buyer,
  item-tax: auto,
  ..args,
) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: zugferd,
  zugferd-errors: "ignore",
  sender: sender,
  recipient: recipient,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(test: (ctx, data) => {
    let signal(kind) = loom.query.find-signal(data, kind)
    test(process-zugferd(
      ctx,
      signal("line-items").item-data,
      payment-goal: signal("payment-goal"),
      bank: signal("bank-details"),
    ))
  })[
    #line-items[
      #if item-tax == auto [#item([Consulting], price: 100)] else [
        #item([Consulting], price: 100, tax: item-tax)
      ]
    ]
    #payment-goal(days: 14)
    #bank-details(
      bank: "Musterbank",
      iban: "DE89370400440532013000",
      bic: "COBADEFFXXX",
    )
  ],
)

// 1. Empty electronic addresses are derived, copied VAT IDs cleaned, and an
//    `id` with scheme is a global identifier
#e-invoice(
  sender: seller
    + (
      vat-id: "\u{200B}DE 123 456 789",
      electronic-address: auto,
      id: (scheme: "0088", id: "4000001123452"),
    ),
  recipient: buyer + (vat-id: "\u{FEFF}FR99123456789", electronic-address: ""),
  result => {
    assert.eq(result.diagnostics, ())
    let xml = str(result.xml)
    for element in (
      "<ram:GlobalID schemeID=\"0088\">4000001123452</ram:GlobalID>",
      "<ram:URIID schemeID=\"9930\">DE123456789</ram:URIID>",
      "<ram:ID schemeID=\"VA\">DE123456789</ram:ID>",
      "<ram:URIID schemeID=\"9957\">FR99123456789</ram:URIID>",
      "<ram:ID schemeID=\"VA\">FR99123456789</ram:ID>",
    ) {
      assert(xml.contains(element), message: element)
    }
    assert(not xml.contains("<ram:URIUniversalCommunication />"))
  },
)

// 2. Not subject to VAT: no VAT identifiers, but the electronic address of the
//    buyer is derived from its VAT ID, so XRechnung is possible
#e-invoice(
  zugferd: "xrechnung",
  tax: tax.outside-scope(grounds: "Not subject to VAT."),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: "10115 Berlin",
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "04011000-12345-67",
  ),
  delivery-address: (name: "Lager", city: "10117 Berlin", location-id: "L-7"),
  result => {
    assert.eq(result.diagnostics, ())
    let xml = str(result.xml)
    assert(xml.contains("<ram:URIID schemeID=\"9930\">DE987654321</ram:URIID>"))
    assert(not xml.contains("schemeID=\"VA\""))
    assert(xml.contains("<ram:ShipToTradeParty><ram:ID>L-7</ram:ID>"))
  },
)

// 3. A VAT ID starting with a multi-byte character is reported, not a crash
#e-invoice(sender: seller + (vat-id: "€123456789"), result => {
  assert.eq(rules(result), ("BR-CO-09",))
})

// 4. Identifiers that cannot all be written are reported, not dropped
#e-invoice(
  sender: seller + (id: "LIEF-0815", global-id: "9012345000004"),
  recipient: buyer
    + (id: "CUST-99", global-id: (scheme: "0088", id: "3000001123459")),
  delivery-address: (
    name: "Lager",
    city: "75003 Paris",
    id: "LAGER-7",
    global-id: (scheme: "0088", id: "3000001123459"),
  ),
  result => {
    assert.eq(rules(result), ("CII-SR-449", "CII-SR-450", "IP-ID-02"))
  },
)

// 5. A recipient without country whose VAT ID and city are Austrian
#e-invoice(
  recipient: (
    name: "Kunde GmbH",
    address: "Ringstraße 2",
    city: "1010 Wien",
    vat-id: "ATU87654321",
  ),
  item-tax: tax.intra-community(),
  result => {
    assert.eq(rules(result), ("IP-ADDR-01", "IP-COUNTRY-01"))
  },
)
