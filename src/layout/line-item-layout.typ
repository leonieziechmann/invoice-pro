#let render-invoice(data) = {
  // 1. Spaltenkonfiguration basierend auf Layout-Infos definieren
  let cols = (
    auto, // Pos
    1fr, // Beschreibung
    auto, // Menge
    auto, // Preis
    auto, // Steuer
    auto, // Gesamt
  )

  // 2. Tabellenzeilen aus den Items generieren
  let item-rows = ()
  for (i, item) in data.items.enumerate() {
    // Baue die Beschreibungs-Spalte dynamisch zusammen
    let description-stack = stack(
      dir: ttb,
      spacing: 0.4em,
      text(weight: "bold", item.name),

      // Optionale Felder anfügen
      ..if item.has-description {
        (text(size: 0.85em, fill: luma(100), item.description),)
      } else { () },
      ..if item.has-date {
        (text(size: 0.85em, style: "italic", item.date),)
      } else { () },

      // Item-Level Rabatte & Zuschläge anzeigen
      ..if item.has-discounts {
        item.discounts.map(d => text(
          size: 0.85em,
          fill: rgb("d32f2f"),
        )[↳ Rabatt: #d.name (#d.display)])
      } else { () },
      ..if item.has-surcharge {
        item.surcharge.map(s => text(
          size: 0.85em,
          fill: rgb("388e3c"),
        )[↳ Zuschlag: #s.name (#s.display)])
      } else { () },
    )

    item-rows.push(str(i + 1))
    item-rows.push(description-stack)
    item-rows.push([#item.quantity #item.unit])
    item-rows.push(item.price)
    item-rows.push([#item.tax.rate #item.tax.category])
    item-rows.push(item.total)
  }

  // 3. Tabelle Zeichnen
  table(
    columns: cols,
    stroke: none,
    align: (x, y) => if x == 1 { left } else if x == 0 { center } else {
      right
    },

    table.hline(stroke: 1pt),
    [*Pos*], [*Beschreibung*], [*Menge*], [*Einzelpreis*], [*MwSt.*], [*Gesamt*],
    table.hline(stroke: 0.5pt),
    ..item-rows,
    table.hline(stroke: 1pt)
  )

  // 4. Zusammenfassung / Totals (Rechtsbündig unter der Tabelle)
  align(right)[
    #box(width: 50%)[
      #grid(
        columns: (1fr, auto),
        row-gutter: 0.6em,
        align: (left, right),

        // Netto
        [Nettobetrag:], data.total.net,

        // Globale Rabatte
        ..data
          .discounts
          .map(d => (
            text(fill: rgb("d32f2f"))[Rabatt: #d.name],
            text(fill: rgb("d32f2f"))[− #d.display],
          ))
          .flatten(),

        // Globale Zuschläge
        ..data
          .surcharges
          .map(s => (
            text(fill: rgb("388e3c"))[Zuschlag: #s.name],
            text(fill: rgb("388e3c"))[\+ #s.display],
          ))
          .flatten(),

        // Steuern aufgeschlüsselt
        ..data
          .taxes
          .map(t => (
            [zzgl. MwSt. #t.rate (#t.category):],
            t.amount,
          ))
          .flatten(),

        // Abschlusslinie für Brutto
        grid.hline(stroke: 1pt),

        // Brutto
        pad(y: 1em, {
          text(weight: "bold", size: 1.2em)[Bruttobetrag: ]
          text(weight: "bold", size: 1.2em)[#data.total.gross]
        }),

        grid.hline(stroke: 1.5pt),
      )
    ]
  ]
}
