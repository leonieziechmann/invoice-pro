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
  let res-en16931-bt34 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (country: country.fr, email: "buyer@example.fr"),
    sender-overrides: (
      vat-id: none,
      contact-name: "Max Mustermann",
      phone: "+49 89 123456",
      email: none,
    ),
  ))
  assert.eq(
    res-en16931-bt34,
    "panicked with: \"e-invoicing (profile 'en16931') requires a seller electronic address (BT-34). Set 'electronic-address', 'vat-id', or 'email' on the sender.\"",
  )

  // (c) Profile xrechnung (domestic DE -> DE): missing buyer electronic address (BT-49)
  let res-xrec-bt49 = catch(() => test-e-invoice(zugferd: "en16931"))
  assert.eq(
    res-xrec-bt49,
    "panicked with: \"e-invoicing (profile 'xrechnung') requires a buyer electronic address (BT-49). Set 'electronic-address', 'vat-id', or 'email' on the recipient.\"",
  )

  // (d) Profile xrechnung: missing buyer reference (BT-10)
  let res-xrec-bt10 = catch(() => test-e-invoice(
    zugferd: "en16931",
    recipient-overrides: (email: "buyer@example.de"),
  ))
  assert.eq(
    res-xrec-bt10,
    "panicked with: \"e-invoicing (profile 'xrechnung') requires a buyer reference (BT-10). Set 'buyer-reference' or 'leitweg-id' on the recipient.\"",
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
    "panicked with: \"e-invoicing (profile 'xrechnung') requires seller contact information (BG-6). Set 'contact' (with name, phone, and email) or 'contact-name', 'phone', and 'email' on the sender.\"",
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
  assert.eq(
    res-xrec-bt41,
    "panicked with: \"e-invoicing (profile 'xrechnung') requires a seller contact name (BT-41). Set 'contact.name' or 'contact-name' on the sender.\"",
  )

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
  assert.eq(
    res-xrec-bt42,
    "panicked with: \"e-invoicing (profile 'xrechnung') requires a seller contact phone number (BT-42). Set 'contact.phone' or 'phone' on the sender.\"",
  )

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
  assert.eq(
    res-xrec-bt43,
    "panicked with: \"e-invoicing (profile 'xrechnung') requires a seller contact email address (BT-43). Set 'contact.email' or 'email' on the sender.\"",
  )
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

