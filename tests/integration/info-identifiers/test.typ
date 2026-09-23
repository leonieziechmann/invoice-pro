// Identifiers of the `id` module printed through `info` and the reference
// signs: the printed invoice shows the identifier as the e-invoice states it
// (BT-10, BT-30, BT-46, BT-47), never the dictionary of the typed identifier
// (`(scheme: "0088", id: .., kind: .., problems: ..)`).

#import "/src/lib.typ": *
#import "/tests/integration/payment-reference/harness.typ": plain

// DIN-5008 theme that records the rendered body and the resolved reference
// signs as metadata.
#let capturing-theme = () => {
  let theme = themes.DIN-5008(font: "libertinus serif")()
  let document(ctx, body) = {
    let captured = metadata((
      body: body,
      references: ctx.references,
      labels: ctx.locale.strings.reference,
    ))
    (theme.document)(ctx, [#body#captured<captured>])
  }
  theme + (document: document)
}

#show: invoice.with(
  theme: capturing-theme,
  locale: locale.en-de,
  zugferd: "en16931",
  references: (references.buyer-reference(),),
  sender: (
    name: "Tech Solutions GmbH",
    address: "Software Allee 10",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456789",
    legal-id: id.register("HRB 98765", court: "Amtsgericht München"),
  ),
  recipient: (
    name: "Stadtwerke Musterstadt GmbH",
    address: "Werkstraße 5",
    city: "12345 Musterstadt",
    country: country.de,
    vat-id: "DE987654321",
    id: id.gln("4000001123452"),
    legal-id: id.register("HRB 4711", court: "Amtsgericht Köln"),
    leitweg-id: id.leitweg("04011000-1234512345-06"),
  ),
  invoice-nr: "INV-2026-0100",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Consulting], quantity: 8, unit: unit.hour, price: 120)
]
#payment-goal(days: 14)

Seller register: #info.sender.legal-id

Buyer register: #info.recipient.legal-id

Buyer reference: #info.buyer-reference

Buyer GLN: #info.dynamic("recipient", "id")

#context {
  let captured = query(<captured>)
  // Introspection is empty in the first layout iteration.
  if captured.len() == 0 { return }
  let (body, references, labels) = captured.first().value

  // The e-invoice states the identifiers without the typed dictionary.
  let xml = str(query(pdf.attach).first().data)
  for (element, value) in (
    ("<ram:BuyerReference>", "04011000-1234512345-06"),
    ("<ram:ID>", "Amtsgericht München, HRB 98765"),
    ("<ram:ID>", "Amtsgericht Köln, HRB 4711"),
    ("<ram:GlobalID schemeID=\"0088\">", "4000001123452"),
  ) {
    let tag = element.slice(1).split(" ").first().trim(">")
    assert(
      xml.contains(element + value + "</" + tag + ">"),
      message: "factur-x.xml: " + element + value,
    )
  }

  // `info`: the lines printed in the body.
  let lines = plain(body).split("\n").map(line => line.trim())
  for (label, value) in (
    ("Seller register", "Amtsgericht München, HRB 98765"),
    ("Buyer register", "Amtsgericht Köln, HRB 4711"),
    ("Buyer reference", "04011000-1234512345-06"),
    ("Buyer GLN", "4000001123452"),
  ) {
    let line = label + ": " + value
    assert(
      line in lines,
      message: "info: expected " + repr(line) + " in " + repr(lines),
    )
  }

  // The reference sign of the buyer reference.
  let label = labels.buyer-reference
  let sign = references.find(((key, _)) => key == label)
  assert.ne(sign, none, message: "reference sign " + repr(label))
  assert.eq(
    plain(sign.at(1)),
    "04011000-1234512345-06",
    message: "reference sign " + label,
  )
}
