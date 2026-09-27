// Shared harness for the payment reference tests.
//
// The payment reference is resolved in one order everywhere: the `reference`
// or `text` argument of `bank-details`, the invoice's `payment-reference`,
// the `invoice-nr`. The harness captures what the document actually prints
// (bank details, EPC-QR payload, reference signs, `info`) and what it actually
// attaches as `factur-x.xml` (BT-83), and asserts that they agree.

#import "/src/lib.typ": *

// --- Capturing ---

#let base-theme = themes.DIN-5008(font: "libertinus serif")

/// DIN-5008 theme that additionally records the printed bank details and the
/// resolved reference signs as metadata.
#let capturing-theme = () => {
  let theme = base-theme()
  let document(ctx, body) = {
    let captured = metadata((
      label: ctx.locale.strings.reference.payment-reference,
      references: ctx.references,
    ))
    (theme.document)(ctx, [#body#captured<captured-references>])
  }
  let bank-details(ctx, view) = {
    let printed = (theme.bank-details)(ctx, view)
    let captured = metadata((
      label: ctx.locale.strings.bank-details.reference,
      printed: printed,
    ))
    [#captured<captured-bank-details>#printed]
  }
  theme + (document: document, bank-details: bank-details)
}

/// A valid XRechnung / EN 16931 invoice showing the payment reference in the
/// reference signs.
#let zugferd-invoice = invoice.with(
  theme: capturing-theme,
  locale: locale.de-de,
  zugferd: "en16931",
  references: (
    references.payment-reference(),
    // What the law requires on the invoice (IP-PRINT-03, IP-PERIOD-03)
    references.seller-tax-nr(),
    references.seller-vat-id(),
    references.service-time(),
  ),
  sender: (
    name: "Test GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 123 456789",
      email: "max@mustermann.de",
    ),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Kundenweg 5",
    city: "54321 Kundenstadt",
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "RE-2026-001",
  date: datetime(year: 2026, month: 7, day: 6),
)

#let standard-items = [
  #line-items[
    #item([Beratungsleistung], price: 100.00, quantity: 10, unit: "hrs")
  ]

  #payment-goal(days: 14)
]

#let bank = (
  bank: "Musterbank",
  iban: "DE07100202005821158846",
  bic: "BHBLDEHHXXX",
)

// --- Extraction ---

/// Plain text of rendered content.
#let plain(it) = {
  if type(it) == str { return it }
  if type(it) != content { return "" }
  let func = it.func()
  if func == text { it.text } else if func in (linebreak, parbreak) {
    "\n"
  } else if func == [ ].func() { " " } else if func == smartquote {
    if it.at("double", default: true) { "\"" } else { "'" }
  } else if it.has("children") {
    it.children.map(plain).join(default: "")
  } else if it.has("child") { plain(it.child) } else if it.has("body") {
    plain(it.body)
  } else { "" }
}

/// All elements of kind `func` within rendered content.
#let find-all(it, func) = {
  if type(it) != content { return () }
  let found = if it.func() == func { (it,) } else { () }
  if it.has("children") {
    for child in it.children { found += find-all(child, func) }
  } else if it.has("child") {
    found += find-all(it.child, func)
  } else if it.has("body") {
    found += find-all(it.body, func)
  }
  found
}

/// The value printed after `label: ` in plain text, or `none`.
#let printed-value(plain-text, label) = {
  let prefix = label + ": "
  let line = plain-text
    .split("\n")
    .map(line => line.trim())
    .find(line => line.starts-with(prefix))
  if line == none { none } else { line.slice(prefix.len()).trim() }
}

#let xml-child(node, tag) = node.children.find(child => (
  type(child) == dictionary and child.tag.split(":").last() == tag
))

/// BT-83 (`ram:PaymentReference`) of a factur-x.xml, or `none`.
#let xml-payment-reference(data) = {
  let node = xml(data).find(child => type(child) == dictionary)
  for tag in (
    "SupplyChainTradeTransaction",
    "ApplicableHeaderTradeSettlement",
    "PaymentReference",
  ) {
    if node == none { return none }
    node = xml-child(node, tag)
  }
  if node == none { none } else { node.children.join() }
}

// --- Assertion ---

/// Asserts that every place showing the payment reference agrees on
/// `expected`, and that the printed text matches the attached factur-x.xml.
///
/// - expected (none, str): The resolved payment reference.
/// - epc-field (str): EPC-QR field that carries it: `"reference"` (line 10,
///   structured) or `"text"` (line 11, unstructured).
/// - bank-details (bool): Whether the document contains bank details.
#let expect-payment-reference(
  expected,
  epc-field: "reference",
  bank-details: true,
) = {
  [#metadata(none)<payment-reference-check>]

  dynamic(
    "payment-reference",
    format: value => [#metadata(value)<captured-info>],
  )

  context {
    // Introspection is empty in the first layout iteration.
    if query(<payment-reference-check>).len() == 0 { return }

    // ZUGFeRD XML (BT-83)
    let attachments = query(pdf.attach).filter(it => (
      it.path == "/factur-x.xml"
    ))
    assert.eq(
      attachments.len(),
      1,
      message: "factur-x.xml: expected 1 attachment, got "
        + str(attachments.len()),
    )
    let xml-value = xml-payment-reference(attachments.first().data)
    assert.eq(
      xml-value,
      expected,
      message: "factur-x.xml BT-83: expected "
        + repr(expected)
        + ", got "
        + repr(xml-value),
    )

    // Printed bank details and EPC-QR payload
    let captured-bank = query(<captured-bank-details>)
    if bank-details {
      assert.eq(
        captured-bank.len(),
        1,
        message: "Bank details: expected 1 printed block, got "
          + str(captured-bank.len()),
      )
      let (label, printed) = captured-bank.first().value

      let printed-reference = printed-value(plain(printed), label)
      assert.eq(
        printed-reference,
        xml-value,
        message: "Printed bank details vs. factur-x.xml: printed "
          + repr(printed-reference)
          + ", XML "
          + repr(xml-value),
      )

      let qr-codes = find-all(printed, image)
      assert.eq(
        qr-codes.len(),
        1,
        message: "EPC-QR: expected 1 code, got " + str(qr-codes.len()),
      )
      // The QR code's alt text is its payload (EPC069-12, one field per line).
      let epc = qr-codes.first().alt.split("\n")
      let (epc-reference, epc-text) = (epc.at(9), epc.at(10))
      let expected-epc = if expected == none { ("", "") } else if (
        epc-field == "reference"
      ) { (expected, "") } else { ("", expected) }
      assert.eq(
        (epc-reference, epc-text),
        expected-epc,
        message: "EPC-QR (reference, text): expected "
          + repr(expected-epc)
          + ", got "
          + repr((epc-reference, epc-text)),
      )
    } else {
      assert.eq(
        captured-bank.len(),
        0,
        message: "Bank details: expected none, got " + str(captured-bank.len()),
      )
    }

    // Reference signs (`references.payment-reference`)
    let (label, references) = query(<captured-references>).first().value
    let reference-sign = references.find(((key, _)) => key == label)
    let reference-value = if reference-sign != none {
      plain(reference-sign.at(1))
    }
    assert.eq(
      reference-value,
      xml-value,
      message: "Reference sign vs. factur-x.xml: printed "
        + repr(reference-value)
        + ", XML "
        + repr(xml-value),
    )

    // `info.payment-reference`
    let captured-info = query(<captured-info>)
    let info-value = if captured-info.len() > 0 {
      plain(captured-info.first().value)
    }
    assert.eq(
      info-value,
      xml-value,
      message: "info.payment-reference vs. factur-x.xml: printed "
        + repr(info-value)
        + ", XML "
        + repr(xml-value),
    )
  }
}
