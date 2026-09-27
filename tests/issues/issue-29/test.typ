// Regression test for GitHub issue #29
// https://github.com/leonieziechmann/invoice-pro/issues/29
//
// Bug reported:
// When mandatory e-invoicing fields (BT-49, BT-10, BG-6) cannot be filled,
// invoice-pro left them out of the XML and emitted the document anyway,
// resulting in XML failing fatal validation rules in e-invoicing validators.
//
// Expected behavior:
// A compile-time error naming the missing field and how to satisfy it.

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
    city: (name: "Mûnnchen", post-code: "80339"),
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
    theme: themes.blank,
    locale: locale.de-de,
    zugferd: zugferd,
    sender: base-sender + sender-overrides,
    recipient: base-recipient + recipient-overrides,
    invoice-nr: "2026-01",
    [
      #line-items[
        #item([Consulting], price: 100, quantity: 1, tax: tax.vat(19%))
      ]
      #payment-goal(days: 14)
      #bank-details(
        bank: "Musterbank",
        iban: "DE89370400440532013000",
        bic: "BANK123X",
      )
    ],
  )
}

// The rules of the errors (or warnings) listed in the compiler error, sorted;
// `()` if the invoice compiles.
#let reported-rules(level: "error", ..args) = {
  let message = catch(() => test-e-invoice(..args))
  if message == none { return () }
  assert(
    message.starts-with("assertion failed: The e-invoice"),
    message: "Unexpected error: " + message,
  )
  let (errors, ..warnings) = message.split("\nWarnings:")
  let section = if level == "error" { errors } else { warnings.join() }
  if section == none { return () }
  section
    .matches(regex("\n  (?:[0-9]+\\.|-) \\[([A-Za-z0-9-]+)\\]"))
    .map(m => m.captures.first())
    .sorted()
}

// --- 1. Assert compile-time errors on missing mandatory fields ---
#{
  // (a) Profile en16931 (cross-border DE -> FR): EN 16931 only recommends the
  //     buyer electronic address (BT-49), so the invoice compiles
  assert.eq(
    reported-rules(
      zugferd: "en16931",
      recipient-overrides: (country: country.fr),
    ),
    (),
  )

  // (b) Profile en16931 (cross-border DE -> FR): without VAT ID, tax number and
  //     email, the seller can neither be identified (BR-CO-26) nor charge VAT
  //     (BR-S-02); the missing seller electronic address (BT-34) is a warning
  //     of invoice-pro's own (IP-EADDR-01), which EN 16931 does not require
  let seller-without-ids = (
    recipient-overrides: (country: country.fr, email: "buyer@example.fr"),
    sender-overrides: (
      vat-id: none,
      contact-name: "Max Mustermann",
      phone: "+49 89 123456",
      email: none,
    ),
  )
  assert.eq(
    reported-rules(zugferd: "en16931", ..seller-without-ids),
    ("BR-CO-26", "BR-S-02"),
  )
  assert.eq(
    reported-rules(level: "warning", zugferd: "en16931", ..seller-without-ids),
    ("IP-EADDR-01",),
  )

  // (c) Profile xrechnung (DE -> DE): every missing field is listed at
  //     once: buyer electronic address (BT-49), buyer reference (BT-10) and
  //     seller contact (BG-6)
  assert.eq(
    reported-rules(zugferd: "xrechnung"),
    ("BR-DE-15", "BR-DE-2", "PEPPOL-EN16931-R010").sorted(),
  )

  // (d) Profile xrechnung: missing buyer reference (BT-10) and seller contact
  assert.eq(
    reported-rules(
      zugferd: "xrechnung",
      recipient-overrides: (email: "buyer@example.de"),
    ),
    ("BR-DE-15", "BR-DE-2"),
  )

  // (e) Profile xrechnung: missing seller contact group (BG-6)
  assert.eq(
    reported-rules(
      zugferd: "xrechnung",
      recipient-overrides: (
        email: "buyer@example.de",
        buyer-reference: "DEI23456789-12345-12",
      ),
    ),
    ("BR-DE-2",),
  )

  // (f) Profile xrechnung: missing individual seller contact components (BT-41, BT-42, BT-43)
  let recipient = (
    email: "buyer@example.de",
    buyer-reference: "DE123456789-12345-12",
  )
  assert.eq(
    reported-rules(
      zugferd: "xrechnung",
      recipient-overrides: recipient,
      sender-overrides: (
        contact: (phone: "+49 89 123456", email: "seller@example.de"),
      ),
    ),
    ("BR-DE-5",),
  )
  assert.eq(
    reported-rules(
      zugferd: "xrechnung",
      recipient-overrides: recipient,
      sender-overrides: (
        contact: (name: "Max Mustermann", email: "seller@example.de"),
      ),
    ),
    ("BR-DE-6",),
  )
  assert.eq(
    reported-rules(
      zugferd: "xrechnung",
      recipient-overrides: recipient,
      sender-overrides: (
        contact: (name: "Max Mustermann", phone: "+49 89 123456"),
      ),
    ),
    ("BR-DE-7",),
  )
}

// --- 1b. Only XRechnung requires these fields ---
#{
  // (g) An explicit "en16931" invoice between German parties stays EN 16931,
  //     which requires none of them
  assert.eq(reported-rules(zugferd: "en16931"), ())

  // (h) `zugferd: auto` falls back to EN 16931 when they are missing
  assert.eq(reported-rules(zugferd: auto), ())
}

// --- 2. Valid full invoice rendering with all mandatory fields satisfied ---
#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
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
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "BANK123X",
)

