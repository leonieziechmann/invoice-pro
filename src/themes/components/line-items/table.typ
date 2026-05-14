#import "../../../utils/types.typ"

#let default-render-description-cell(ctx, item, layout, styles) = {
  stack(
    dir: ttb,
    spacing: 0.4em,
    text(weight: styles.weight-bold, item.name),
    ..if item.has-description and layout.show-descriptions {
      (
        text(
          size: styles.size-small,
          fill: styles.color-desc,
          item.description,
        ),
      )
    } else { () },
    ..if item.has-date and layout.show-dates {
      (text(size: styles.size-small, style: "italic", item.date),)
    } else { () },
  )
}

#let default-render-header-cell(ctx, content, styles) = {
  table.cell(fill: styles.header-bg, inset: styles.cell-inset)[
    #set text(fill: styles.header-color)
    #content
  ]
}

#let default-render-table-header(ctx, header-cells, styles) = {
  table.header(
    repeat: styles.header-repeat,
    table.hline(stroke: styles.stroke-header-top),
    ..header-cells,
    table.hline(stroke: styles.stroke-header-bottom),
  )
}

#let default-render-tax-suffix(ctx, is-net, styles, style-type) = {
  let strings = ctx.locale.strings.line-items
  let label = if is-net { strings.net } else { strings.gross }

  if style-type == "newline" {
    (
      [\ ]
        + text(
          size: 0.8em,
          weight: "regular",
          fill: styles.color-subtitle,
        )[(#label)]
    )
  } else if style-type == "inline" {
    (
      [ ]
        + text(
          size: 0.8em,
          weight: "regular",
          fill: styles.color-subtitle,
        )[(#label)]
    )
  } else if style-type == "accent" {
    (
      [ ]
        + text(
          size: 0.7em,
          weight: "bold",
          fill: styles.color-subtitle.lighten(20%),
        )[#upper(label)]
    )
  } else {
    []
  }
}

#let render-table(
  ctx,
  data,
  color-subtitle: luma(80),
  color-desc: luma(100),
  color-row-odd: rgb("e2e8f0"),
  color-row-even: none,
  color-discount: rgb("b22222"),
  color-surcharge: rgb("333333"),
  size-subtitle: 0.85em,
  size-small: 0.85em,
  weight-bold: "bold",
  stroke-thin: 0.5pt,
  stroke-regular: 1pt,
  cell-inset: (top: 0.125em, bottom: 0.125em),
  // Structural parameters
  column-order: ("quantity", "unit-price", "tax-rate", "total-price"),
  render-description-cell: auto,
  render-discount-row: auto,
  render-surcharge-row: auto,
  render-subtotal-row: auto,
  // Header/Footer parameters
  header-bg: none,
  header-color: black,
  header-repeat: true,
  stroke-header-top: auto,
  stroke-header-bottom: auto,
  stroke-table-bottom: auto,
  render-header-cell: auto,
  render-table-header: auto,
  render-table-footer: auto,
  // Tax suffix parameters
  tax-suffix-style: "newline",
  render-tax-suffix: auto,
) = {
  types.require(color-subtitle, "render-table::color-subtitle", color, none)
  types.require(color-desc, "render-table::color-desc", color, none)
  types.require(color-row-odd, "render-table::color-row-odd", color, none)
  types.require(color-row-even, "render-table::color-row-even", color, none)
  types.require(color-discount, "render-table::color-discount", color, none)
  types.require(color-surcharge, "render-table::color-surcharge", color, none)

  types.require(weight-bold, "render-table::weight-bold", str, int)

  types.require(stroke-thin, "render-table::stroke-thin", stroke, length, none)
  types.require(
    stroke-regular,
    "render-table::stroke-regular",
    stroke,
    length,
    none,
  )

  let strings = ctx.locale.strings
  let li-str = strings.line-items

  let layout = data.layout-information
  let is-net = data.tax-mode == "exclusive"

  let s-header-top = if stroke-header-top == auto { stroke-regular } else {
    stroke-header-top
  }
  let s-header-bottom = if stroke-header-bottom == auto { stroke-thin } else {
    stroke-header-bottom
  }
  let s-table-bottom = if stroke-table-bottom == auto { stroke-regular } else {
    stroke-table-bottom
  }

  let styles = (
    color-subtitle: color-subtitle,
    color-desc: color-desc,
    color-discount: color-discount,
    color-surcharge: color-surcharge,
    size-subtitle: size-subtitle,
    size-small: size-small,
    weight-bold: weight-bold,
    header-bg: header-bg,
    header-color: header-color,
    header-repeat: header-repeat,
    stroke-header-top: s-header-top,
    stroke-header-bottom: s-header-bottom,
    stroke-table-bottom: s-table-bottom,
    cell-inset: cell-inset,
  )

  set par(justify: false)

  // Resolve suffix styles
  let resolve-suffix-style(key) = {
    if type(tax-suffix-style) == str {
      tax-suffix-style
    } else if type(tax-suffix-style) == dictionary {
      tax-suffix-style.at(key, default: "newline")
    } else {
      "newline"
    }
  }

  let get-suffix(key) = {
    if render-tax-suffix == auto {
      let s-type = resolve-suffix-style(key)
      default-render-tax-suffix(ctx, is-net, styles, s-type)
    } else {
      render-tax-suffix(ctx, is-net, styles, key)
    }
  }

  // --- Dynamic Column Setup ---
  let cols = ()
  let raw-headers = ()
  let aligns = ()

  // Left columns are fixed: Position (if enabled) and Description
  if layout.show-pos {
    cols.push(auto)
    raw-headers.push([*#li-str.position*])
    aligns.push(center)
  }

  cols.push(1fr)
  raw-headers.push([*#li-str.description*])
  aligns.push(left)

  // Map requested column order to headers and styles
  let available-cols = (
    "quantity": (
      enabled: layout.show-quantity,
      header: [*#li-str.quantity*],
      align: right,
    ),
    "unit-price": (
      enabled: layout.show-unit-price,
      header: [*#li-str.unit-price*#get-suffix("unit-price")],
      align: right,
    ),
    "tax-rate": (
      enabled: layout.show-tax-rates,
      header: [*#li-str.vat*],
      align: right,
    ),
    "total-price": (
      enabled: layout.show-total-price,
      header: [*#li-str.total*#get-suffix("total")],
      align: right,
    ),
  )

  let active-cols-keys = ()
  for col-key in column-order {
    if col-key in available-cols {
      let col = available-cols.at(col-key)
      if col.enabled {
        cols.push(auto)
        raw-headers.push(col.header)
        aligns.push(col.align)
        active-cols-keys.push(col-key)
      }
    }
  }

  // Calculate absolute indices for alignment
  let total-cols = cols.len()
  let colspan-left = if layout.show-pos { 1 } else { 0 }
  let desc-idx = colspan-left

  let total-price-idx = active-cols-keys.position(k => k == "total-price")
  let abs-total-idx = if total-price-idx != none {
    desc-idx + 1 + total-price-idx
  } else {
    none
  }

  let abs-percent-idx = if total-price-idx != none and total-price-idx > 0 {
    abs-total-idx - 1
  } else {
    none
  }

  // --- Header Construction ---
  let header-cells = raw-headers.map(h => {
    if render-header-cell == auto {
      default-render-header-cell(ctx, h, styles)
    } else {
      render-header-cell(ctx, h, styles)
    }
  })

  let table-header = if render-table-header == auto {
    default-render-table-header(ctx, header-cells, styles)
  } else {
    render-table-header(ctx, header-cells, styles)
  }

  let table-footer = if render-table-footer == auto {
    ()
  } else {
    render-table-footer(ctx, total-cols, styles)
  }

  let item-rows = ()

  // --- Item Row Rendering ---
  for (i, item) in data.items.enumerate() {
    let has-modifications = (
      (item.has-discounts or item.has-surcharge) and layout.show-modifier
    )

    let bg = if calc.odd(i) { color-row-odd } else { color-row-even }
    let cell = table.cell.with(fill: bg, stroke: none)
    let cell-spacing = (inset: cell-inset, fill: bg)

    // 1. Position
    if layout.show-pos {
      item-rows.push(cell(str(i + 1)))
    }

    // 2. Description
    let desc-content = if render-description-cell == auto {
      default-render-description-cell(ctx, item, layout, styles)
    } else {
      render-description-cell(ctx, item, layout, styles)
    }
    item-rows.push(cell(desc-content))

    // 3. Dynamic Columns
    for col-key in active-cols-keys {
      let content = if col-key == "quantity" {
        if layout.show-units { [#item.quantity #item.unit] } else {
          [#item.quantity]
        }
      } else if col-key == "unit-price" {
        item.price
      } else if col-key == "tax-rate" {
        [#item.tax.rate #item.tax.category]
      } else if col-key == "total-price" {
        if has-modifications and item.keys().contains("unmodified-total") {
          item.unmodified-total
        } else {
          item.total
        }
      }
      item-rows.push(cell(content))
    }

    // --- Discounts ---
    if item.has-discounts and layout.show-modifier {
      for d in item.discounts {
        if render-discount-row == auto {
          let row = ()
          if layout.show-pos { row.push(cell(..cell-spacing)[]) }

          let label = text(
            size: size-small,
            fill: color-discount,
          )[↳ #li-str.discount: #d.name]
          let percent = if d.is-percent {
            text(fill: color-discount)[(− #d.display)]
          } else { [] }
          let total-val = text(fill: color-discount)[− #d.absolute]

          if abs-total-idx != none {
            if abs-percent-idx != none {
              row.push(cell(
                colspan: abs-percent-idx - desc-idx,
                align: left,
                ..cell-spacing,
              )[#label])
              row.push(cell(align: right, ..cell-spacing)[#percent])
              row.push(cell(align: right, ..cell-spacing)[#total-val])
            } else {
              row.push(cell(
                colspan: abs-total-idx - desc-idx,
                align: left,
                ..cell-spacing,
              )[#label])
              row.push(cell(align: right, ..cell-spacing)[#percent #total-val])
            }
            let remaining = total-cols - (abs-total-idx + 1)
            if remaining > 0 {
              row.push(cell(colspan: remaining, ..cell-spacing)[])
            }
          } else {
            row.push(cell(
              colspan: total-cols - colspan-left - 1,
              align: left,
              ..cell-spacing,
            )[#label])
            row.push(cell(align: right, ..cell-spacing)[#percent #total-val])
          }
          item-rows += row
        } else {
          item-rows += render-discount-row(
            ctx,
            d,
            layout,
            (
              left: colspan-left,
              desc: desc-idx,
              total: abs-total-idx,
              percent: abs-percent-idx,
              total-count: total-cols,
            ),
            styles,
            cell-spacing,
          )
        }
      }
    }

    // --- Surcharges ---
    if item.has-surcharge and layout.show-modifier {
      for s in item.surcharge {
        if render-surcharge-row == auto {
          let row = ()
          if layout.show-pos { row.push(cell(..cell-spacing)[]) }

          let label = text(
            size: size-small,
            fill: color-surcharge,
          )[↳ #li-str.surcharge: #s.name]
          let percent = if s.is-percent {
            text(fill: color-surcharge)[(\+ #s.display)]
          } else { [] }
          let total-val = text(fill: color-surcharge)[\+ #s.absolute]

          if abs-total-idx != none {
            if abs-percent-idx != none {
              row.push(cell(
                colspan: abs-percent-idx - desc-idx,
                align: left,
                ..cell-spacing,
              )[#label])
              row.push(cell(align: right, ..cell-spacing)[#percent])
              row.push(cell(align: right, ..cell-spacing)[#total-val])
            } else {
              row.push(cell(
                colspan: abs-total-idx - desc-idx,
                align: left,
                ..cell-spacing,
              )[#label])
              row.push(cell(align: right, ..cell-spacing)[#percent #total-val])
            }
            let remaining = total-cols - (abs-total-idx + 1)
            if remaining > 0 {
              row.push(cell(colspan: remaining, ..cell-spacing)[])
            }
          } else {
            row.push(cell(
              colspan: total-cols - colspan-left - 1,
              align: left,
              ..cell-spacing,
            )[#label])
            row.push(cell(align: right, ..cell-spacing)[#percent #total-val])
          }
          item-rows += row
        } else {
          item-rows += render-surcharge-row(
            ctx,
            s,
            layout,
            (
              left: colspan-left,
              desc: desc-idx,
              total: abs-total-idx,
              percent: abs-percent-idx,
              total-count: total-cols,
            ),
            styles,
            cell-spacing,
          )
        }
      }
    }

    // --- Subtotal per Item ---
    if has-modifications {
      if render-subtotal-row == auto {
        let row = ()
        if layout.show-pos { row.push(cell(fill: bg)[]) }

        let label = text(
          size: size-small,
          weight: weight-bold,
          fill: color-subtitle,
        )[#li-str.subtotal #li-str.position #str(i + 1):]
        let total-val = text(weight: weight-bold)[#item.total]

        if abs-total-idx != none {
          row.push(cell(
            colspan: abs-total-idx - desc-idx,
            align: left,
            fill: bg,
          )[#label])
          row.push(cell(align: right, fill: bg)[#total-val])
          let remaining = total-cols - (abs-total-idx + 1)
          if remaining > 0 { row.push(cell(colspan: remaining, fill: bg)[]) }
        } else {
          row.push(cell(
            colspan: total-cols - colspan-left - 1,
            align: left,
            fill: bg,
          )[#label])
          row.push(cell(align: right, fill: bg)[#total-val])
        }
        item-rows += row
      } else {
        item-rows += render-subtotal-row(
          ctx,
          i + 1,
          item.total,
          layout,
          (
            left: colspan-left,
            desc: desc-idx,
            total: abs-total-idx,
            percent: abs-percent-idx,
            total-count: total-cols,
          ),
          styles,
          bg,
        )
      }
    }
  }

  table(
    columns: cols,
    stroke: none,
    align: (x, y) => aligns.at(x, default: right),
    table-header,
    ..item-rows,
    ..table-footer,
    table.hline(stroke: s-table-bottom)
  )
}
