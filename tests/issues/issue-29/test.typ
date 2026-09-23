// Regression test for GitHub issue #29
// https://github.com/leonieziechmann/invoice-pro/issues/29
//
// Bug reported:
// When mandatory e-invoicing fields (BT-49, BT-10, BG-6) cannot be filled,
// invoice-pro left them out of the XML and emitted the document anyway,
// resulting in XML failing fatal validation rules in e-invoicing validators.
//
// Expected behavior:
// A compile-time error naming the missing field and how to satisfy it. Since
// the validation levels, `validation: "strict"` stops the build and lists every
// missing field at once (the default "draft" renders the document, marks the
// problems and withholds the XML).

#import "/src/lib.typ": *

// Helper to construct test invoices with varying sender/recipient parameters
#let test-e-invoice(
  sender-overrides: (:),
  recipient-overrides: (:),
  zugferd: "en16931",
) = {
  let base-sender = (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "Mûnnchen", post-code: "80339"),
    country: country.de,
    vat-id: "DE123456789",
  )
  let base-recipient = (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
  )
  invoice(
    theme: theme.plain,
    locale: locale.de-de,
    validation: "strict",
    zugferd: zugferd,
    sender: base-sender + sender-overrides,
    recipient: base-recipient + recipient-overrides,
    invoice-nr: "2026-01",
    [
      #line-items[
        #item([Consulting], price: 100, quantity: 1, tax: tax.vat(19%))
      ]
      #payment-terms(days: 14)
      #bank-details(
        bank: "Musterbank",
        iban: "DE89370400440532013000",
        bic: "BANK123X",
      )
    ],
  )
}

// The strict panic as `catch` reports it: one problem keeps its message
// verbatim, several are numbered under a header line.
#let strict-panic(..messages) = {
  let m = messages.pos()
  let text = if m.len() == 1 { m.first() } else {
    (
      "invoice-pro found "
        + str(m.len())
        + " problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):\n"
        + m.enumerate().map(((i, x)) => "  " + str(i + 1) + ". " + x).join("\n")
    )
  }
  "panicked with: " + repr(text)
}

// en16931 between two German parties is checked (and written) as XRechnung.
#let xrechnung = (
  bt49: "e-invoicing (profile 'en16931' applied as 'xrechnung') requires a buyer electronic address (BT-49). Set 'electronic-address', 'vat-id', or 'email' on the recipient.",
  bt10: "e-invoicing (profile 'en16931' applied as 'xrechnung') requires a buyer reference (BT-10). Set 'buyer-reference' or 'leitweg-id' on the recipient.",
  bt41: "e-invoicing (profile 'en16931' applied as 'xrechnung') requires a seller contact name (BT-41). Set 'contact.name' or 'contact-name' on the sender.",
  bt42: "e-invoicing (profile 'en16931' applied as 'xrechnung') requires a seller contact phone number (BT-42). Set 'contact.phone' or 'phone' on the sender.",
  bt43: "e-invoicing (profile 'en16931' applied as 'xrechnung') requires a seller contact email address (BT-43). Set 'contact.email' or 'email' on the sender.",
)

// --- 1. Assert compile-time panics on missing mandatory fields ---
#{
  // (a) Profile en16931 (cross-border DE -> FR): missing buyer electronic address (BT-49)
  let res-en16931-bt49 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (country: country.fr),
  ))
  assert.eq(
    res-en16931-bt49,
    "panicked with: \"e-invoicing (profile 'en16931') requires a buyer electronic address (BT-49). Set 'electronic-address', 'vat-id', or 'email' on the recipient.\"",
  )

  // (b) Profile en16931 (cross-border DE -> FR): missing seller electronic address (BT-34)
  // (the tax number keeps the supplier's tax ID, required by § 14 UStG, in place)
  let res-en16931-bt34 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (country: country.fr, email: "buyer@example.fr"),
    sender-overrides: (
      vat-id: none,
      tax-nr: "123/456/78901",
      contact-name: "Max Mustermann",
      phone: "+49 89 123456",
      email: none,
    ),
  ))
  assert.eq(
    res-en16931-bt34,
    "panicked with: \"e-invoicing (profile 'en16931') requires a seller electronic address (BT-34). Set 'electronic-address', 'vat-id', or 'email' on the sender.\"",
  )

  // (c) Profile xrechnung (domestic DE -> DE): the reported invoice misses the
  // buyer electronic address (BT-49), the buyer reference (BT-10) and the
  // seller contact (BG-6: BT-41, BT-42, BT-43); strict names all of them
  let res-xrec-bt49 = catch(() => test-e-invoice(zugferd: "en16931"))
  assert.eq(
    res-xrec-bt49,
    strict-panic(
      xrechnung.bt49,
      xrechnung.bt10,
      xrechnung.bt41,
      xrechnung.bt42,
      xrechnung.bt43,
    ),
  )

  // (d) Profile xrechnung: missing buyer reference (BT-10) and seller contact
  let res-xrec-bt10 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (email: "buyer@example.de"),
  ))
  assert.eq(
    res-xrec-bt10,
    strict-panic(
      xrechnung.bt10,
      xrechnung.bt41,
      xrechnung.bt42,
      xrechnung.bt43,
    ),
  )

  // (e) Profile xrechnung: missing seller contact group (BG-6)
  let res-xrec-bg6 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (
      email: "buyer@example.de",
      buyer-reference: "DEI23456789-12345-12",
    ),
  ))
  assert.eq(
    res-xrec-bg6,
    strict-panic(xrechnung.bt41, xrechnung.bt42, xrechnung.bt43),
  )

  // (f) Profile xrechnung: missing individual seller contact components (BT-41, BT-42, BT-43)
  let res-xrec-bt41 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (
      email: "buyer@example.de",
      buyer-reference: "DE123456789-12345-12",
    ),
    sender-overrides: (
      contact: (phone: "+49 89 123456", email: "seller@example.de"),
    ),
  ))
  assert.eq(res-xrec-bt41, strict-panic(xrechnung.bt41))

  let res-xrec-bt42 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (
      email: "buyer@example.de",
      buyer-reference: "DE123456789-12345-12",
    ),
    sender-overrides: (
      contact: (name: "Max Mustermann", email: "seller@example.de"),
    ),
  ))
  assert.eq(res-xrec-bt42, strict-panic(xrechnung.bt42))

  let res-xrec-bt43 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (
      email: "buyer@example.de",
      buyer-reference: "DE123456789-12345-12",
    ),
    sender-overrides: (
      contact: (name: "Max Mustermann", phone: "+49 89 123456"),
    ),
  ))
  assert.eq(res-xrec-bt43, strict-panic(xrechnung.bt43))
}

// --- 2. Valid full invoice rendering with all mandatory fields satisfied ---
// strict: any missing field fails the test, and the XML is always built
// (draft would withhold it and skip the builder)
#show: invoice.with(
  theme: theme.plain,
  locale: locale.de-de,
  validation: "strict",
  zugferd: "en16931",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "Musterstadt", post-code: "80339"),
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "seller@example.de",
    ),
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    email: "buyer@example.de",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "2026-01",
)

#line-items[
  #item([Consulting], price: 100, quantity: 1, tax: tax.vat(19%))
]
#payment-terms(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "BANK123X",
)
