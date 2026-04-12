#let render-line-items(ctx, data, body) = {
  // --- Styling Variables ---
  let color-subtitle = luma(80)
  let color-desc = luma(100)

  let color-row-odd = rgb("e2e8f0")
  let color-discount = rgb("b22222")
  let color-surcharge = rgb("333333")
  let color-vat-label = rgb("475569")

  let size-subtitle = 0.85em
  let size-small = 0.85em
  let size-total = 1.2em

  let weight-bold = "bold"

  let stroke-thin = 0.5pt
  let stroke-regular = 1pt
  let stroke-thick = 2pt

  let cell-inset = (top: 0.125em, bottom: 0.125em)
  let totals-width = 66%
  let totals-row-gutter = 0.6em

  // --- Table Configuration & Flags ---
  let all-qty-one = data.items.all(item => str(item.quantity) == "1")
  let show-qty-price = not all-qty-one

  let unique-tax-rates = data.items.map(item => item.tax.rate).dedup()
  let show-tax = unique-tax-rates.len() > 1

  let is-net = data.tax-mode == "exclusive"

  let cols = (auto, 1fr)
  let headers = ([*Pos*], [*Beschreibung*])
  let aligns = (center, left)

  let subtitle = text.with(
    size: size-subtitle,
    weight: weight-bold,
    fill: color-subtitle,
  )

  // --- Column & Header Setup ---
  set par(justify: false)

  if show-qty-price {
    cols.push(auto)
    headers.push([*Menge*])
    aligns.push(right)

    cols.push(auto)
    headers.push(align(
      center,
      if is-net [*Einzelpreis* \ #subtitle[(Netto)]] else [*Einzelpreis* \ #subtitle[(Brutto)]],
    ))
    aligns.push(right)
  }

  if show-tax {
    cols.push(auto)
    headers.push([*MwSt.*])
    aligns.push(right)
  }

  cols.push(auto)
  headers.push(align(
    center,
    if is-net [*Gesamt* \ #subtitle[(Netto)]] else [*Gesamt* \ #subtitle[(Brutto)]],
  ))
  aligns.push(right)

  let colspan-desc = if show-tax { cols.len() - 3 } else { cols.len() - 2 }
  let item-rows = ()

  // --- Item Rows Generation ---
  for (i, item) in data.items.enumerate() {
    let has-modifications = item.has-discounts or item.has-surcharge

    let bg = if calc.odd(i) { color-row-odd } else { none }

    let cell = table.cell.with(fill: bg, stroke: none)

    let description-stack = stack(
      dir: ttb,
      spacing: 0.4em,
      text(weight: weight-bold, item.name),
      ..if item.has-description {
        (text(size: size-small, fill: color-desc, item.description),)
      } else { () },
      ..if item.has-date {
        (text(size: size-small, style: "italic", item.date),)
      } else { () },
    )

    item-rows.push(cell(str(i + 1)))
    item-rows.push(cell(description-stack))

    if show-qty-price {
      item-rows.push(cell([#item.quantity #item.unit]))
      item-rows.push(cell(item.price))
    }
    if show-tax {
      item-rows.push(cell([#item.tax.rate #item.tax.category]))
    }

    if has-modifications and item.keys().contains("unmodified-total") {
      item-rows.push(cell(str(item.unmodified-total)))
    } else {
      item-rows.push(cell(item.total))
    }

    let cell-spacing = (inset: cell-inset, fill: bg)

    // --- Discount Handling ---
    if item.has-discounts {
      for d in item.discounts {
        item-rows.push(cell(..cell-spacing)[])

        item-rows.push(cell(
          colspan: colspan-desc,
          align: left,
          ..cell-spacing,
        )[
          #text(size: size-small, fill: color-discount)[↳ Rabatt: #d.name]
        ])

        item-rows.push(cell(..cell-spacing, colspan: if show-tax {
          2
        } else { 1 })[
          #text(
            fill: color-discount,
          )[#if d.is-percent [(− #d.display) #h(.5em)]]
          #text(fill: color-discount)[− #d.absolute]
        ])
      }
    }

    // --- Surcharge Handling ---
    if item.has-surcharge {
      for s in item.surcharge {
        item-rows.push(cell(..cell-spacing)[])

        item-rows.push(cell(
          colspan: colspan-desc,
          align: left,
          ..cell-spacing,
        )[
          #text(size: size-small, fill: color-surcharge)[↳ Zuschlag: #s.name]
        ])

        item-rows.push(cell(..cell-spacing, colspan: if show-tax {
          2
        } else { 1 })[
          #text(
            fill: color-surcharge,
          )[#if s.is-percent [(\+ #s.display) #h(.5em)]]
          #text(fill: color-surcharge)[\+ #s.absolute]
        ])
      }
    }

    // --- Subtotal per Item ---
    if has-modifications {
      item-rows.push(cell[])
      item-rows.push(cell(
        colspan: if show-tax { colspan-desc + 1 } else { colspan-desc },
        align: left,
        fill: bg,
      )[
        #text(
          size: size-small,
          weight: weight-bold,
          fill: color-subtitle,
        )[Zwischensumme Pos. #str(i + 1):]
      ])

      item-rows.push(cell[#text(
        weight: weight-bold,
      )[#item.total]])
    }
  }

  // --- Table Rendering ---
  table(
    columns: cols,
    stroke: none,
    align: (x, y) => aligns.at(x, default: right),

    table.header(
      repeat: true,
      table.hline(stroke: stroke-regular),
      ..headers,
      table.hline(stroke: stroke-thin),
    ),
    ..item-rows,
    table.hline(stroke: stroke-regular)
  )

  // --- Summary & Totals Box ---
  align(right)[
    #box(width: totals-width, {
      if data.tax-mode == "inclusive" {
        grid(
          columns: (1fr, auto),
          row-gutter: totals-row-gutter,
          column-gutter: 1em,
          align: (left, right),

          // Only show Brutto subtotal if there are actually modifiers
          ..if data.discounts.len() > 0 or data.surcharges.len() > 0 {
            (
              [Zwischensumme (Brutto):],
              data.unmodified-total.gross,
            )
          } else { () },

          ..data
            .discounts
            .map(d => (
              text(fill: color-discount, size-small)[Rabatt: #d.name],
              text(
                fill: color-discount,
              )[#if d.is-percent [(− #d.display) #h(.5em)] − #d.absolute],
            ))
            .flatten(),

          ..data
            .surcharges
            .map(s => (
              text(fill: color-surcharge, size-small)[Zuschlag: #s.name],
              text(
                fill: color-surcharge,
              )[#if s.is-percent [(\+ #s.display) #h(.5em)] \+ #s.absolute],
            ))
            .flatten(),

          grid.hline(stroke: stroke-thick),

          pad(top: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[Bruttobetrag:]),
          pad(top: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[#data.total.gross]),

          grid.hline(stroke: stroke-thick), [], [],

          ..data
            .taxes
            .map(t => (
              text(fill: color-vat-label)[inkl. MwSt. #t.rate (#t.category):],
              text(fill: black)[#t.amount],
            ))
            .flatten(),

          pad(y: -.5em)[], pad(y: -.5em)[],
          pad(bottom: 0.3em)[], pad(bottom: 0.3em)[],
        )
      } else {
        grid(
          columns: (1fr, auto),
          row-gutter: totals-row-gutter,
          column-gutter: 1em,
          align: (left, right),

          [Zwischensumme (Netto):], data.unmodified-total.net,

          ..data
            .discounts
            .map(d => (
              text(fill: color-discount, size-small)[Rabatt: #d.name],
              text(
                fill: color-discount,
              )[#if d.is-percent [(− #d.display) #h(.5em)] − #d.absolute],
            ))
            .flatten(),

          ..data
            .surcharges
            .map(s => (
              text(fill: color-surcharge, size-small)[Zuschlag: #s.name],
              text(
                fill: color-surcharge,
              )[#if s.is-percent [(+ #s.display) #h(.5em)] \+ #s.absolute],
            ))
            .flatten(),

          ..if data.discounts.len() > 0 or data.surcharges.len() > 0 {
            (
              text(weight: weight-bold)[Gesamt Netto:],
              text(weight: weight-bold)[#data.total.net],
            )
          } else { () },

          grid.hline(stroke: stroke-thin),

          pad(top: 0.3em)[], pad(top: 0.3em)[],

          ..data
            .taxes
            .map(t => (
              text(fill: color-vat-label)[zzgl. MwSt. #t.rate (#t.category):],
              text(fill: black)[#t.amount],
            ))
            .flatten(),

          pad(y: -.5em)[], pad(y: -.5em)[],
          pad(bottom: 0.3em)[], pad(bottom: 0.3em)[],

          grid.hline(stroke: stroke-thick),

          pad(y: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[Bruttobetrag:]),
          pad(y: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[#data.total.gross]),

          grid.hline(stroke: stroke-thick),
        )
      }
    })
  ]

  // --- Global Tax Information ---
  if not show-tax and unique-tax-rates.len() == 1 {
    let tax-rate = unique-tax-rates.first()
    let tax-text = if is-net { "zzgl." } else { "inkl." }
    pad(top: 0.5em, bottom: 1em, align(right)[
      #text(
        size: size-small,
        style: "italic",
        fill: color-desc,
      )[Alle Positionen verstehen sich #tax-text #tax-rate MwSt.]
    ])
  }

  body
}
