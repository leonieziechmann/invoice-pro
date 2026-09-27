// The small business scheme of each region (`tax-exempt-small-biz: true`).
//
// The legal note printed on the invoice is the exemption reason (BT-120) of
// the attached e-invoice (factur-x.xml, or xrechnung.xml in the XRECHNUNG
// profile), and the VAT category (BT-118) says why no VAT is
// charged: E where the law exempts the turnover of small businesses (DE § 19
// Abs. 1 UStG since 2025, AT § 6 Abs. 1 Z 27 UStG, FR art. 293 B du CGI, ES),
// O where they are not subject to VAT (IT regime forfettario, CH).
//
// Bugs:
// - DE, AT, FR and ES were written as O ("not subject to VAT"), contradicting
//   the printed note. O also drops the VAT identifiers (BR-O-02): a small
//   business with only a VAT ID could not issue an e-invoice (BR-CO-26), and
//   the buyer's electronic address was not derived from its VAT ID
//   (PEPPOL-EN16931-R010 under XRechnung).
// - German-language invoices of other regions (e.g. `de-at`) printed the
//   German "§ 19 UStG" in front of the region's own legal note.

#import "/src/lib.typ": *

#let default-line-items = themes.blank().line-items

/// Plain text of rendered content.
#let plain(it) = {
  if type(it) == str { return it }
  if type(it) != content { return "" }
  let func = it.func()
  if func == text { it.text } else if func in (linebreak, parbreak) {
    "\n"
  } else if func == [ ].func() { " " } else if it.has("children") {
    it.children.map(plain).join(default: "")
  } else if it.has("child") { plain(it.child) } else if it.has("body") {
    plain(it.body)
  } else { "" }
}

/// The child elements of an XML node with the local name `tag`.
#let xml-children(node, tag) = node.children.filter(child => (
  type(child) == dictionary and child.tag.split(":").last() == tag
))

/// The node at a path of local names below `node`, or `none`.
#let xml-at(node, ..tags) = {
  for tag in tags.pos() {
    if node == none { return none }
    node = xml-children(node, tag).first(default: none)
  }
  node
}

#let xml-text(node) = if node == none { none } else { node.children.join() }

/// The tax registrations of a trade party as `(scheme: id)`.
#let registrations(party) = {
  let ids = (:)
  for registration in xml-children(party, "SpecifiedTaxRegistration") {
    let id = xml-at(registration, "ID")
    ids.insert(id.attrs.schemeID, xml-text(id))
  }
  ids
}

#let de-note = "Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gemäß § 19 Abs. 1 UStG."
#let at-note = "Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gem. § 6 Abs. 1 Z 27 UStG."

#let cases = (
  (
    name: "de-de, seller with only a VAT ID",
    locale: locale.de-de,
    sender: (
      city: (name: "Berlin", post-code: "10115"),
      country: country.de,
      vat-id: "DE123456789",
    ),
    recipient: (city: (name: "Köln", post-code: "50667"), country: country.de),
    category: "E",
    note: de-note,
  ),
  (
    name: "de-de, XRechnung, buyer without email",
    locale: locale.de-de,
    zugferd: "xrechnung",
    sender: (
      city: (name: "Berlin", post-code: "10115"),
      country: country.de,
      vat-id: "DE123456789",
    ),
    recipient: (
      city: (name: "Köln", post-code: "50667"),
      country: country.de,
      vat-id: "DE987654321",
      buyer-reference: "04011000-12345-34",
    ),
    buyer-email: false,
    category: "E",
    note: de-note,
  ),
  (
    name: "en-de, seller with only a tax number",
    locale: locale.en-de,
    sender: (
      city: (name: "Berlin", post-code: "10115"),
      country: country.de,
      tax-nr: "30/123/45678",
    ),
    recipient: (city: (name: "Köln", post-code: "50667"), country: country.de),
    category: "E",
    note: de-note,
    printed: "No VAT is charged due to small business exemption. ("
      + de-note
      + ")",
  ),
  (
    name: "de-at",
    locale: locale.de-at,
    sender: (
      city: (name: "Wien", post-code: "1060"),
      country: country.at,
      vat-id: "ATU12345678",
    ),
    recipient: (city: (name: "Graz", post-code: "8010"), country: country.at),
    category: "E",
    note: at-note,
    printed: "Aufgrund der Kleinunternehmerregelung wird keine Umsatzsteuer berechnet. ("
      + at-note
      + ")",
  ),
  (
    name: "fr-fr",
    locale: locale.fr-fr,
    sender: (
      city: (name: "Paris", post-code: "75001"),
      country: country.fr,
      vat-id: "FR40303265045",
    ),
    recipient: (city: (name: "Lyon", post-code: "69001"), country: country.fr),
    category: "E",
    note: "TVA non applicable, art. 293 B du CGI.",
  ),
  (
    name: "es-es",
    locale: locale.es-es,
    sender: (
      city: (name: "Madrid", post-code: "28013"),
      country: country.es,
      vat-id: "ES12345678Z",
    ),
    recipient: (
      city: (name: "Sevilla", post-code: "41004"),
      country: country.es,
    ),
    category: "E",
    note: "Exento de IVA según el régimen especial de franquicia para pequeñas empresas.",
  ),
  (
    name: "it-it",
    locale: locale.it-it,
    sender: (
      city: (name: "Milano", post-code: "20121"),
      country: country.it,
      tax-nr: "MSTNNA80A41F205X",
    ),
    recipient: (
      city: (name: "Torino", post-code: "10124"),
      country: country.it,
    ),
    category: "O",
    note: "Operazione in franchigia da IVA ai sensi dell'art. 1, commi da 54 a 89, della Legge n. 190/2014.",
  ),
  (
    name: "de-ch",
    locale: locale.de-ch,
    sender: (
      city: (name: "Zürich", post-code: "8001"),
      country: country.ch,
      id: "CHE-123.456.789",
    ),
    recipient: (city: (name: "Bern", post-code: "3011"), country: country.ch),
    category: "O",
    note: "Nicht MWST-pflichtig / Non soumis à la TVA / Non assoggettato all'IVA",
  ),
)

#for case in cases {
  invoice(
    theme: themes.blank.with(line-items: (ctx, data, body) => {
      let printed = default-line-items(ctx, data, body)
      [#metadata(plain(printed))<printed-line-items>#printed]
    }),
    locale: case.locale,
    zugferd: case.at("zugferd", default: "en16931"),
    tax-exempt-small-biz: true,
    sender: (
      name: "Anna Muster",
      address: "Hauptstraße 1",
      contact: (
        name: "Anna Muster",
        phone: "+49 30 1234567",
        email: "anna@muster.example",
      ),
    )
      + case.sender,
    recipient: (name: "Kunde", address: "Weg 5")
      + case.recipient
      + if case.at("buyer-email", default: true) {
        (email: "rechnung@kunde.example")
      },
    invoice-nr: "KU-2026-001",
    date: datetime(year: 2026, month: 9, day: 1),
  )[
    #line-items[
      #item([Beratung], price: 100, quantity: 2)
    ]
    #payment-goal(days: 14)
    #bank-details(
      bank: "Musterbank",
      iban: "DE89370400440532013000",
      bic: "COBADEFFXXX",
    )
  ]
}

#metadata(none)<small-biz-regions-check>

#context {
  // Introspection is empty in the first layout iteration.
  if query(<small-biz-regions-check>).len() == 0 { return }
  let printed = query(<printed-line-items>).map(it => it.value)
  let attachments = query(pdf.attach).filter(it => (
    it.path in ("/factur-x.xml", "/xrechnung.xml")
  ))
  assert.eq(printed.len(), cases.len(), message: "printed line items")
  assert.eq(attachments.len(), cases.len(), message: "attached XML files")

  for (i, case) in cases.enumerate() {
    let doc = xml(attachments.at(i).data).find(n => type(n) == dictionary)
    let trade = xml-at(doc, "SupplyChainTradeTransaction")
    let tax = xml-at(
      trade,
      "ApplicableHeaderTradeSettlement",
      "ApplicableTradeTax",
    )
    assert.eq(
      xml-text(xml-at(tax, "CategoryCode")),
      case.category,
      message: case.name + ": VAT category (BT-118)",
    )
    assert.eq(
      xml-text(xml-at(tax, "RateApplicablePercent")),
      "0.00",
      message: case.name + ": VAT rate (BT-119)",
    )
    assert.eq(
      xml-text(xml-at(tax, "ExemptionReason")),
      case.note,
      message: case.name + ": exemption reason (BT-120)",
    )

    // The printed note is the exemption reason of the XML.
    let expected = case.at("printed", default: case.note)
    assert(
      printed.at(i).contains(expected),
      message: case.name
        + ": expected the printed note "
        + repr(expected)
        + ", got "
        + repr(printed.at(i)),
    )
    if not case.note.contains("§ 19 UStG") {
      assert(
        not printed.at(i).contains("§ 19 UStG"),
        message: case.name + ": the note cites the German § 19 UStG",
      )
    }

    // An exempt small business keeps its VAT identifier (BR-E-02); one that
    // is not subject to VAT states none (BR-O-02).
    let agreement = xml-at(trade, "ApplicableHeaderTradeAgreement")
    let seller = registrations(xml-at(agreement, "SellerTradeParty"))
    assert.eq(
      seller.at("VA", default: none),
      if case.category == "E" { case.sender.at("vat-id", default: none) },
      message: case.name + ": seller VAT identifier (BT-31)",
    )

    // The buyer's electronic address (BT-49) is derived from its VAT ID.
    let buyer-vat-id = case.recipient.at("vat-id", default: none)
    if buyer-vat-id != none {
      let address = xml-at(
        agreement,
        "BuyerTradeParty",
        "URIUniversalCommunication",
        "URIID",
      )
      assert.ne(address, none, message: case.name + ": BT-49 missing")
      assert.eq(
        (address.attrs.schemeID, xml-text(address)),
        ("9930", buyer-vat-id),
        message: case.name + ": buyer electronic address (BT-49)",
      )
    }
  }
}
