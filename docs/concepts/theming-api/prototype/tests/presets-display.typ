// presets-display checks (scripts/checks-presets-display.sh): the bold and compact
// presets on a plain German invoice.
//   --input preset=bold|compact  --input n=<items>  --input deposit=1
//   --input layout=<name> (default: the preset's own, by region)  --input seed=<hex>
//   --input broken=1  no invoice number and no seller tax ID (validation draft
//                     markers must render sensibly inside the look)
// Every text run that names the payable amount ("Fälliger Betrag" after a deposit,
// "Gesamtbetrag" otherwise) leaves a metadata marker <pd-label>, so the script can
// count them with `typst query` (bold: the poster block and the totals bar must use
// the same words).
#import "/src/lib.typ": *

#let preset = dictionary(theme).at(sys.inputs.at("preset", default: "bold"))
#let lay = sys.inputs.at("layout", default: none)
#let seed = sys.inputs.at("seed", default: none)
#let n = int(sys.inputs.at("n", default: "4"))
#let broken = sys.inputs.at("broken", default: "0") == "1"
#let ids = if broken { (:) } else {
  (vat-id: "DE123456789", tax-nr: "22 123 45678")
}

#show regex("(?i)fälliger betrag"): it => [#it#metadata("amount-due")<pd-label>]
#show regex("(?i)gesamtbetrag"): it => [#it#metadata("total")<pd-label>]

#show: invoice.with(
  theme: preset.with(
    if seed != none { theme.custom.brand(color: rgb("#" + seed)) },
    ..if lay != none { (layout: dictionary(theme.layout).at(lay)) },
  ),
  locale: locale.de-de,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    ..ids,
    register: [Amtsgericht Hamburg HRB 123456],
    management: [GF: Lina Berg],
    extra: (
      Telefon: "+49 40 1234567",
      "E-Mail": "rechnung@atelier-nord-hamburg.de",
    ),
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  ..if not broken { (invoice-nr: "2026-0142") },
  customer-nr: "K-2201",
  subject: "Leistungen September",
)

Sehr geehrte Damen und Herren, für unsere Leistungen im September berechnen wir:

#line-items[
  #for i in range(n) {
    item(
      [Leistungsposition #(i + 1)],
      item-id: (seller: "A-" + str(1000 + i)),
      unit: unit.hour,
      quantity: 1 + calc.rem(i, 4),
      price: 85 + 5 * calc.rem(i, 7),
      description: if calc.rem(i, 5)
        == 0 [Beschreibung der Leistung, Ort und Datum],
    )
  }
  #if sys.inputs.at("deposit", default: "0") == "1" {
    prepayment(500, name: [Abschlag])
  }
]

#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature()
