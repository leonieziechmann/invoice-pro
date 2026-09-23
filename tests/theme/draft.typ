// The draft fixture (prototype tests/validation/draft.typ): a real invoice with
// four open problems: the invoice number, the supplier's tax ID, the
// recipient's address (data) and the buyer's electronic address that the
// en16931 profile requires (e-invoice). Its inline markers link to the report,
// so a document holds one such draft invoice.
#import "/src/lib.typ": *

#let draft-ids = (
  "invoice-number",
  "sender-tax-id",
  "recipient-address",
  "e-invoice/buyer-address",
)

/// look: a preset name; lang: de | en | fr | it | es; validation: the level.
/// -> content
#let draft-invoice(
  look: "classic",
  lang: "de",
  validation: "draft",
  marker: none,
) = invoice(
  theme: dictionary(theme).at(look),
  locale: (
    de: locale.de-de,
    en: locale.en-de,
    fr: locale.fr-de,
    it: locale.it-de,
    es: locale.es-de,
  ).at(lang),
  validation: validation,
  zugferd: "en16931",
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    email: "hallo@atelier-nord.de",
    register: [Amtsgericht Hamburg HRB 123456],
    management: [GF: Lina Berg],
    extra: (Telefon: "+49 40 1234567", "E-Mail": "hallo@atelier-nord.de"),
  ),
  recipient: (name: "Bergbahn Tirol GmbH", region: "at"),
  customer-nr: "K-2201",
  references: (references.customer-nr(),),
  [
    #marker
    Sehr geehrte Damen und Herren, für unsere Leistungen im September berechnen wir:

    #line-items[
      #item(
        [Konzeption Corporate Design],
        price: 1800,
        description: [Workshops, Moodboards, zwei Entwurfsrunden],
      )
      #item([Logo-Reinzeichnung], price: 650)
      #item([Geschäftsausstattung], price: 95, quantity: 4)
      #item([Druckabwicklung], price: 240)
    ]

    #payment-terms(days: 14)
    #bank-details(
      bank: "Hamburger Sparkasse",
      iban: "DE75512108001245126199",
      bic: "SOLADEST600",
    )
    #signature()
  ],
)

/// The report exists only under draft; it is not counted as an invoice page.
/// Needs `context`.
#let assert-draft(ids: draft-ids) = {
  let issues = query(<ip-issue>).map(m => m.value.id).dedup()
  assert(issues == ids, message: repr(issues))
  assert(query(<ip-report>).len() == 1, message: "no draft report")
}
