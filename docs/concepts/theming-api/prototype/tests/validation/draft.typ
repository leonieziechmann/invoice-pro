// validation: "draft" on a real invoice with four open problems:
// invoice number, supplier tax ID, recipient address (data) and the buyer's
// electronic address required by the en16931 profile (e-invoice).
// --input look=<preset>  --input lang=de|en|fr|it|es  --input level=draft|none|strict
#import "/src/lib.typ": *

#let look = sys.inputs.at("look", default: "classic")
#let lang = sys.inputs.at("lang", default: "de")
#let level = sys.inputs.at("level", default: "draft")
#let th = dictionary(theme).at(look)
#let loc = (
  de: locale.de-de,
  en: locale.en-de,
  fr: locale.fr-de,
  it: locale.it-de,
  es: locale.es-de,
).at(lang)

#show: invoice.with(
  theme: th,
  locale: loc,
  validation: if level == "none" { none } else { level },
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
)

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

// self-checks: the report exists only under draft, and it is not counted
#context {
  let issues = query(<ip-issue>).map(m => m.value.id).dedup()
  let report = query(<ip-report>)
  if level == "draft" {
    assert(
      issues
        == (
          "invoice-number",
          "sender-tax-id",
          "recipient-address",
          "e-invoice/buyer-address",
        ),
      message: repr(issues),
    )
    assert(report.len() == 1)
  } else {
    assert(issues.len() == 0 and report.len() == 0)
  }
}
