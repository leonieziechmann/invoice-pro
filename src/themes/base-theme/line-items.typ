#import "../components/line-items/line-items.typ" as generic-line-items

/// Default base theme line items
#let render-line-items(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    color-subtitle: luma(80),
    color-desc: luma(100),
    color-row-odd: rgb("e2e8f0"),
    color-row-even: none,
    color-discount: rgb("b22222"),
    color-surcharge: rgb("333333"),
    color-vat-label: rgb("475569"),
    size-subtitle: 0.85em,
    size-small: 0.85em,
    size-total: 1.2em,
    weight-bold: "bold",
    stroke-thin: 0.5pt,
    stroke-regular: 1pt,
    stroke-thick: 2pt,
    cell-inset: (top: 0.125em, bottom: 0.125em),
    totals-width: 66%,
    totals-row-gutter: 0.6em,
  )
}

/// An elegant theme with a minimalist header
#let render-line-items-elegant(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    color-row-odd: none,
    stroke-header-top: 2pt + black,
    stroke-header-bottom: none,
    stroke-table-bottom: 2pt + black,
    tax-suffix-style: "inline",
    show-redundant-taxes: false,
    // Header Customization
    render-header-cell: (ctx, content, styles) => {
      table.cell(inset: (y: 0.8em))[
        #set text(size: 0.75em, tracking: 0.2em, weight: "bold")
        #upper(content)
      ]
    },
    render-table-header: (ctx, header-cells, styles) => {
      table.header(
        repeat: true,
        table.hline(stroke: 2pt + black),
        ..header-cells,
        table.hline(stroke: 0.5pt + black),
        table.cell(colspan: header-cells.len(), inset: 0pt, v(2pt)),
        table.hline(stroke: 0.5pt + black),
      )
    },
  )
}

/// A modern vibrant theme with rounded header buttons
#let render-line-items-vibrant(ctx, data, body) = {
  let accent = rgb("#ec4899") // Pink

  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    color-row-odd: accent.lighten(95%),
    stroke-header-top: none,
    stroke-header-bottom: none,
    stroke-table-bottom: 2pt + accent,
    tax-suffix-style: "none",
    // Header
    render-header-cell: (ctx, content, styles) => {
      table.cell(inset: 0.4em, align: center + horizon)[
        #place(block(
          width: 100%,
          height: 100%,
          fill: accent,
          radius: 1em,
          outset: (x: 0.2em, y: 0.4em),
        ))
        #pad(x: 0.4em, text(fill: white, weight: "bold", size: 0.8em, content))
      ]
    },
    render-table-header: (ctx, header-cells, styles) => {
      table.header(repeat: true, ..header-cells)
    },
  )
}

/// A luxury theme with custom styling
#let render-line-items-luxury(ctx, data, body) = {
  let gold = rgb("#b8860b")

  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    color-subtitle: gold,
    color-discount: red.darken(20%),
    color-surcharge: blue.darken(20%),
    weight-bold: "bold",
    stroke-regular: 2pt + black,
    stroke-thin: 1pt + gold,
    cell-inset: (top: 0.5em, bottom: 0.5em),
  )
}

/// An informational theme
#let render-line-items-informational(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    stroke-table-bottom: none,
    tax-suffix-style: (unit-price: "none", total: "accent"),
    color-subtitle: rgb("#2563eb"),
    render-table-footer: (ctx, total-cols, styles) => {
      (
        table.footer(
          repeat: false,
          table.cell(
            colspan: total-cols,
            stroke: (top: 1pt + black),
            inset: (top: 1.5em, bottom: 1em),
          )[
            #set text(size: 0.8em, fill: luma(100))
            *Final Note:* Thank you for your business. Please ensure payment is made within 14 days to the bank details below.
          ],
        ),
      )
    },
  )
}
