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

/// A theme that demonstrates column reordering
#let render-line-items-reordered(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    // Swap Total and Quantity/Price positions
    column-order: ("total-price", "tax-rate", "unit-price", "quantity"),
    color-row-odd: luma(245),
    stroke-regular: 1pt + black,
  )
}

/// A modern, compact theme with a custom description layout
#let render-line-items-compact(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    column-order: ("quantity", "total-price"), // Very minimal columns
    color-row-odd: none,
    stroke-regular: 1.5pt + gray.lighten(50%),
    stroke-thin: 0.5pt + gray.lighten(80%),
    // Custom description: Name and Date on the same line
    render-description-cell: (ctx, item, layout, styles) => {
      block(
        width: 100%,
        {
          text(weight: "bold", item.name)
          if item.has-date and layout.show-dates {
            h(1fr)
            text(size: 0.8em, style: "italic", fill: gray, item.date)
          }
          if item.has-description and layout.show-descriptions {
            v(0.2em)
            text(size: 0.85em, fill: luma(120), item.description)
          }
        },
      )
    },
  )
}

/// A luxury theme with custom row rendering for modifiers
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
    // Custom subtotal row rendering
    render-subtotal-row: (ctx, pos, total, layout, colspans, styles, bg) => {
      let cell = table.cell.with(fill: bg, stroke: (top: 1pt + gold))
      let row = ()
      if colspans.left > 0 {
        row.push(cell([]))
      }

      let label = text(
        fill: gold,
        weight: "bold",
        size: 0.9em,
      )[Subtotal Item #pos:]
      let total-val = text(weight: "bold")[#total]

      if colspans.total != none {
        row.push(cell(
          colspan: colspans.total - colspans.desc,
          align: right,
        )[#label])
        row.push(cell(align: right)[#total-val])
        let remaining = colspans.total-count - (colspans.total + 1)
        if remaining > 0 {
          row.push(cell(colspan: remaining)[])
        }
      } else {
        row.push(cell(
          colspan: colspans.total-count - colspans.left - 1,
          align: right,
        )[#label])
        row.push(cell(align: right)[#total-val])
      }
      row
    },
  )
}

/// A corporate theme with dark headers and a repeating footer
#let render-line-items-corporate(ctx, data, body) = {
  let corp-blue = rgb("#1e3a8a")

  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    header-bg: corp-blue,
    header-color: white,
    stroke-header-top: 2pt + black,
    stroke-header-bottom: 1.5pt + corp-blue,
    stroke-table-bottom: 2pt + black,
    // Add a repeating footer inside the table
    render-table-footer: (ctx, total-cols, styles) => {
      (
        table.footer(
          repeat: true,
          table.cell(
            colspan: total-cols,
            align: center,
            inset: 0.4em,
          )[
            #set text(size: 0.7em, fill: gray, style: "italic")
            --- #ctx.locale.strings.line-items.position continued on next page ---
          ],
        ),
      )
    },
  )
}

/// An elegant theme with a minimalist header and double lines
#let render-line-items-elegant(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    color-row-odd: none,
    stroke-header-top: 2pt + black,
    stroke-header-bottom: none,
    stroke-table-bottom: 2pt + black,
    tax-suffix-style: (unit-price: none, total: "inline"),
    // Custom header: All caps with tracking
    render-header-cell: (ctx, content, styles) => {
      table.cell(inset: (y: 0.8em))[
        #set text(
          size: 0.75em,
          tracking: 0.2em,
          weight: "bold",
        )
        #upper(content)
      ]
    },
    // Custom table header to add double lines
    render-table-header: (ctx, header-cells, styles) => {
      table.header(
        repeat: true,
        table.hline(stroke: 2pt + black),
        ..header-cells,
        table.hline(stroke: 0.5pt + black),
        table.cell(colspan: header-cells.len())[#v(-7pt)],
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
    tax-suffix-style: "none", // Hide suffix for clean buttons
    // Custom header: Rounded buttons for each header
    render-header-cell: (ctx, content, styles) => {
      table.cell(inset: 0.4em, align: center + horizon)[
        #place(
          block(
            width: 100%,
            height: 100%,
            fill: accent,
            radius: 1em,
            outset: (x: 0.2em, y: 0.4em),
          ),
        )
        #pad(
          x: 0.4em,
          text(
            fill: white,
            weight: "bold",
            size: 0.8em,
            content,
          ),
        )
      ]
    },
    // Custom table header to remove all default lines
    render-table-header: (ctx, header-cells, styles) => {
      table.header(repeat: true, ..header-cells)
    },
  )
}

/// An informational theme with a non-repeating final footer
#let render-line-items-informational(ctx, data, body) = {
  generic-line-items.render-line-items(
    ctx,
    data,
    body,
    stroke-table-bottom: none,
    tax-suffix-style: (unit-price: "none", total: "accent"),
    color-subtitle: rgb("#2563eb"), // Bright blue suffix
    render-table-footer: (ctx, total-cols, styles) => {
      (
        table.footer(
          repeat: false, // Only at the very end
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
