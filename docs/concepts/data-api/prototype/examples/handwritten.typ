// The invoice of data/2026-0042.json (SYNTHESIS.md §3.10) written by hand
// with the 0.6.0 components: the twin the hydrated skeleton.typ must equal
// byte for byte. `--input lib=pristine` compiles it with invoice-pro 0.6.0,
// `--input lib=repo` (default) with the prototype. 0.6.0 has no custom
// fields, so the tariff is written out and the Munich arms (the data's
// `custom.wappen`) are chosen by hand.
#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *

#let d(y, m, day) = datetime(year: y, month: m, day: day)

#show: invoice.with(
  theme: theme.classic.with(theme.custom.logo(
    image: image("wappen/muenchen.svg", alt: "Wappen"),
    height: 18mm,
  )),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Entsorgung Süd GmbH",
    address: "Industriestraße 7",
    city: "80339 München",
    country: "DE",
    vat-id: "DE123456789",
    contact: (
      name: "Buchhaltung",
      phone: "+49 89 1234567",
      email: "rechnung@entsorgung-sued.example",
    ),
  ),
  invoice-nr: "2026-0042",
  date: d(2026, 11, 2),
  service-period: (d(2026, 10, 1), d(2026, 10, 31)),
  customer-nr: "K-10077",
  order-nr: "PO-7781",
  project: "Gewerbeentsorgung 2026",
  notes: (
    "Vielen Dank für Ihren Auftrag.",
    (text: "Leistungen gemäß Rahmenvertrag RV-2025-03.", subject-code: "AAI"),
  ),
  recipient: (
    name: "Bayerische Beispiel AG",
    address: ("Marienplatz 8", "z. Hd. Einkauf"),
    city: (name: "München", post-code: "80331"),
    country: "DE",
    vat-id: "DE987654321",
    buyer-reference: "04011000-1234512345-06",
    electronic-address: "einkauf@beispiel-ag.example",
    contact: (name: "Max Einkauf", email: "einkauf@beispiel-ag.example"),
  ),
)

Tarif: Gewerbe M

#line-items[
  #item(
    "Leerung Restmüll 1100 l",
    quantity: "8",
    unit: unit.pcs,
    price: "38.90",
    tax: 19%,
    date: (d(2026, 10, 1), d(2026, 10, 31)),
    item-id: (seller: "RM-1100"),
  )
  #group("Sonderleistungen", show-subtotal: true)[
    #item("Sperrmüllabholung", date: d(2026, 10, 17), price: "45.00", tax: 19%)
    #item(
      "Behälterreinigung",
      quantity: "2",
      unit: unit.pcs,
      price: "15.00",
      tax: 19%,
      modifier: discount("Kulanz", amount: 50%),
    )
    #item("Gutachten Abfallbilanz", total: "80.00", tax: tax.exempt(
      grounds: "Steuerfrei nach § 4 Nr. 21 UStG",
      code: "VATEX-EU-132",
    ))
  ]
  #bundle("Starterpaket Gewerbe", quantity: "1", unit: unit.unit-set)[
    #item("Wertstofftonne 240 l", price: "29.00", tax: 19%)
    #item("Sortierleitfaden (Druck)", price: "4.50", tax: 7%)
    #discount("Paketpreis", amount: "3.50")
  ]
  #item(
    "Strom Presscontainer",
    quantity: "120",
    unit: (code: "KWH", display: "kWh"),
    price: "0.32",
    tax: 19%,
  )
  #surcharge("Energiekostenzuschlag", amount: 2.5%)
  #prepayment(
    "100.00",
    name: "Abschlag Oktober",
    date: d(2026, 10, 5),
    reference: "AB-2026-0117",
  )
]

// The payment means: `--input pay=direct-debit` (default, §3.10), or the
// variants of the payment matrix (proto/payment/p6.sh).
#let pay = sys.inputs.at("pay", default: "direct-debit")
#let terms = payment-terms(days: 14, discount: (days: 7, percent: 2%))
#let account = bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#if pay == "direct-debit" {
  terms
  direct-debit(
    mandate: "MND-2025-0815",
    creditor-id: "DE98ZZZ09999999999",
    debtor-iban: "DE02120300000000202051",
  )
} else if pay == "transfer" {
  terms
  account
} else if pay == "card" {
  terms
  card-payment(last4: "4242", holder: "Max Einkauf", kind: "credit")
} else if pay == "paid-cash" {
  paid(method: "cash", date: d(2026, 11, 2))
} else if pay == "paid-transfer" {
  paid(method: "transfer", date: d(2026, 11, 2))
  account
}

#signature()
