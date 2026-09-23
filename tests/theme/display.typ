// The presets-display fixture (prototype tests/presets-display.typ): the bold and
// compact presets on a plain German invoice. Every text run that names the
// payable amount ("Fälliger Betrag" after a deposit, "Gesamtbetrag" otherwise)
// leaves a metadata marker <pd-label> (bold: the poster block and the totals bar
// must use the same words).
//   n: <items>   deposit: true   layout: <name> (default: the preset's own)
//   seed: <hex>  broken: true (no invoice number and no seller tax ID)
#import "/src/lib.typ": *

#let display-invoice(
  preset,
  n: 4,
  deposit: false,
  layout: none,
  seed: none,
  broken: false,
  validation: "draft",
  marker: none,
) = {
  let ids = if broken { (:) } else {
    (vat-id: "DE123456789", tax-nr: "22 123 45678")
  }
  show regex("(?i)fälliger betrag"): it => [#it#metadata(
      "amount-due",
    )<pd-label>]
  show regex("(?i)gesamtbetrag"): it => [#it#metadata("total")<pd-label>]
  invoice(
    theme: dictionary(theme)
      .at(preset)
      .with(
        if seed != none { theme.custom.brand(color: rgb("#" + seed)) },
        ..if layout != none { (layout: dictionary(theme.layout).at(layout)) },
      ),
    locale: locale.de-de,
    validation: validation,
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
    [
      #marker
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
        #if deposit { prepayment(500, name: [Abschlag]) }
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
}
