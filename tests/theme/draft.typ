// The draft fixture (prototype tests/validation/draft.typ): a real invoice with
// three open problems of its data: the invoice number, the supplier's tax ID
// and the recipient's address. Its en16931 e-invoice is withheld while they are
// open, so the rules of the profile are not checked yet (the prototype also
// listed the buyer's electronic address). Its inline markers link to the
// report, so a document holds one such draft invoice.
#import "/src/lib.typ": *

#let draft-ids = (
  "invoice-number",
  "sender-tax-id",
  "recipient-address",
)

/// look: a preset name; lang: de | en | fr | it | es; validation: the level;
/// zugferd-errors: what happens with the errors of the e-invoice, which are
/// checked when nothing withholds its XML (`validation: none`).
/// -> content
#let draft-invoice(
  look: "classic",
  lang: "de",
  validation: "draft",
  zugferd-errors: "panic",
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
  zugferd-errors: zugferd-errors,
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
