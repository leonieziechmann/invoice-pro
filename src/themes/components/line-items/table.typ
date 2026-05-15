#import "../../../utils/types.typ"
#import "columns.typ": get-column-metadata

// --- Default Renderers ---

#let default-render-title-cell(
  ctx,
  item,
  layout,
  styles,
  is-sub-item: false,
) = {
  let prefix = if is-sub-item { h(1em) + "↳ " } else { "" }

  stack(
    dir: ttb,
    spacing: 0.4em,
    text(
      weight: if is-sub-item { "regular" } else { styles.weight-bold },
      [#prefix #item.name],
    ),
    ..if item.has-date and layout.show-dates {
      let date-indent = if is-sub-item { h(2.2em) } else { "" }
      (
        text(
          size: styles.size-small,
          style: "italic",
          [#date-indent #item.date],
        ),
      )
    } else { () },
  )
}

#let default-render-description-row(
  ctx,
  item,
  layout,
  styles,
  colspan-info,
  cell-spacing,
) = {
  let row = ()
  if layout.show-pos { row.push(table.cell(..cell-spacing)[]) }

  row.push(table.cell(
    colspan: colspan-info.colspan,
    ..cell-spacing,
  )[
    #set text(size: styles.size-small, fill: styles.color-desc)
    #item.description
  ])

  if colspan-info.remaining > 0 {
    row.push(table.cell(colspan: colspan-info.remaining, ..cell-spacing)[])
  }
  row
}

#let default-render-modifier-row(
  ctx,
  mod,
  layout,
  indices,
  styles,
  cell-spacing,
  is-discount: true,
) = {
  let strings = ctx.locale.strings.line-items
  let row = ()
  if layout.show-pos { row.push(table.cell(..cell-spacing)[]) }

  let color = if is-discount { styles.color-discount } else {
    styles.color-surcharge
  }
  let label-str = if is-discount { strings.discount } else { strings.surcharge }
  let sign = if is-discount { "−" } else { "+" }

  let label = text(
    size: styles.size-small,
    fill: color,
  )[↳ #label-str: #mod.name]
  let percent = if mod.is-percent {
    text(fill: color)[(#sign #mod.display)]
  } else { [] }
  let total-val = text(fill: color)[#sign #mod.absolute]

  if indices.total != none {
    if indices.percent != none {
      row.push(table.cell(
        colspan: indices.percent - indices.desc,
        align: left,
        ..cell-spacing,
      )[#label])
      row.push(table.cell(align: right, ..cell-spacing)[#percent])
      row.push(table.cell(align: right, ..cell-spacing)[#total-val])
    } else {
      row.push(table.cell(
        colspan: indices.total - indices.desc,
        align: left,
        ..cell-spacing,
      )[#label])
      row.push(table.cell(align: right, ..cell-spacing)[#percent #total-val])
    }
    let remaining = indices.total-count - (indices.total + 1)
    if remaining > 0 {
      row.push(table.cell(colspan: remaining, ..cell-spacing)[])
    }
  } else {
    row.push(table.cell(
      colspan: indices.total-count - indices.left - 1,
      align: left,
      ..cell-spacing,
    )[#label])
    row.push(table.cell(align: right, ..cell-spacing)[#percent #total-val])
  }
  row
}

#let default-render-group-row(ctx, item, total-cols, styles, cell-spacing) = {
  (
    table.cell(
      colspan: total-cols,
      fill: styles.color-row-odd.darken(5%),
      align: left,
      inset: (x: 0.5em, y: 0.6em),
      ..cell-spacing,
    )[
      #set text(weight: styles.weight-bold, fill: styles.color-subtitle)
      #upper(item.name)
    ],
  )
}

#let default-render-header-cell(ctx, content, styles) = {
  table.cell(fill: styles.header-bg, inset: styles.header-cell-inset)[
    #set text(fill: styles.header-color)
    #content
  ]
}

#let default-render-table-header(ctx, header-cells, styles) = {
  table.header(
    repeat: styles.header-repeat,
    table.hline(stroke: styles.stroke-header-top),
    table.cell(colspan: header-cells.len(), inset: 0pt, []),
    ..header-cells,
    table.cell(colspan: header-cells.len(), inset: 0pt, []),
    table.hline(stroke: styles.stroke-header-bottom),
  )
}

#let default-render-tax-suffix(ctx, is-net, styles, style-type) = {
  let strings = ctx.locale.strings.line-items
  let label = if is-net { strings.net } else { strings.gross }
  let fill-color = styles.color-subtitle

  if style-type == "newline" {
    block(spacing: .2em, text(
      size: 0.8em,
      weight: "regular",
      fill: fill-color,
      [(#label)],
    ))
  } else if style-type == "inline" {
    text(size: 0.8em, weight: "regular", fill: fill-color)[(#label)]
  } else if style-type == "accent" {
    text(size: 0.7em, weight: "bold", fill: fill-color.lighten(20%))[#upper(
      label,
    )]
  } else { none }
}

// --- Logic Helpers ---

#let compute-desc-colspan(
  total-cols,
  desc-idx,
  active-cols-keys,
  colspan-spec,
) = {
  if type(colspan-spec) == int {
    if colspan-spec > 0 { return colspan-spec }
    return calc.max(1, total-cols - desc-idx + colspan-spec)
  } else if type(colspan-spec) == array {
    let count = 1
    for key in active-cols-keys {
      if key in colspan-spec { count += 1 } else { break }
    }
    return count
  }
  return 1
}

// --- Main Function ---

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
  header-cell-inset: (top: 0.5em, bottom: 0.5em),
  column-order: ("quantity", "unit-price", "tax-rate", "total-price"),
  render-title-cell: auto,
  render-description-row: auto,
  desc-colspan: auto,
  render-discount-row: auto,
  render-surcharge-row: auto,
  render-subtotal-row: auto,
  render-group-row: auto,
  header-bg: none,
  header-color: black,
  header-repeat: true,
  stroke-header-top: auto,
  stroke-header-bottom: auto,
  stroke-table-bottom: auto,
  render-header-cell: auto,
  render-table-header: auto,
  render-table-footer: auto,
  tax-suffix-style: "newline",
  render-tax-suffix: auto,
) = {
  let layout = data.layout-information
  let is-net = data.tax-mode == "exclusive"
  let li-str = ctx.locale.strings.line-items

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
    stroke-header-top: if stroke-header-top == auto { stroke-regular } else {
      stroke-header-top
    },
    stroke-header-bottom: if stroke-header-bottom == auto { stroke-thin } else {
      stroke-header-bottom
    },
    stroke-table-bottom: if stroke-table-bottom == auto {
      stroke-regular
    } else { stroke-table-bottom },
    cell-inset: cell-inset,
    header-cell-inset: header-cell-inset,
    color-row-odd: color-row-odd,
    color-row-even: color-row-even,
  )

  set par(justify: false)

  // Pre-resolve callbacks
  let do-render-title = if render-title-cell == auto {
    default-render-title-cell
  } else { render-title-cell }
  let do-render-desc = if render-description-row == auto {
    default-render-description-row
  } else {
    render-description-row
  }
  let do-render-header-cell = if render-header-cell == auto {
    default-render-header-cell
  } else { render-header-cell }
  let do-render-table-header = if render-table-header == auto {
    default-render-table-header
  } else {
    render-table-header
  }
  let do-render-discount = if render-discount-row == auto {
    default-render-modifier-row.with(is-discount: true)
  } else {
    render-discount-row
  }
  let do-render-surcharge = if render-surcharge-row == auto {
    default-render-modifier-row.with(is-discount: false)
  } else { render-surcharge-row }
  let do-render-group = if render-group-row == auto {
    default-render-group-row
  } else { render-group-row }

  let get-suffix(key) = {
    if render-tax-suffix != auto {
      return render-tax-suffix(ctx, is-net, styles, key)
    }
    let s-type = if type(tax-suffix-style) == str { tax-suffix-style } else if (
      type(tax-suffix-style) == dictionary
    ) {
      tax-suffix-style.at(key, default: "newline")
    } else { "newline" }
    default-render-tax-suffix(ctx, is-net, styles, s-type)
  }

  // Column Setup
  let meta = get-column-metadata(data, column-order)
  let (
    cols,
    active-keys: active-cols-keys,
    total-count: total-cols,
    left-count: colspan-left,
    desc-idx,
    total-idx: abs-total-idx,
    percent-idx: abs-percent-idx,
  ) = meta
  let indices = (
    left: colspan-left,
    desc: desc-idx,
    total: abs-total-idx,
    percent: abs-percent-idx,
    total-count: total-cols,
  )

  // Header Construction
  let raw-headers = ()
  if layout.show-pos { raw-headers.push([*#li-str.position*]) }
  raw-headers.push([*#li-str.description*])

  let available-cols = (
    "quantity": [*#li-str.quantity*],
    "unit-price": [*#li-str.unit-price*#get-suffix("unit-price")],
    "tax-rate": [*#li-str.vat*],
    "total-price": [*#li-str.total*#get-suffix("total")],
  )
  for key in active-cols-keys { raw-headers.push(available-cols.at(key)) }

  let table-header = do-render-table-header(
    ctx,
    raw-headers.map(h => do-render-header-cell(ctx, h, styles)),
    styles,
  )
  let table-footer = if render-table-footer != auto {
    render-table-footer(ctx, total-cols, styles)
  } else { () }
  let abs-desc-colspan = compute-desc-colspan(
    total-cols,
    desc-idx,
    active-cols-keys,
    desc-colspan,
  )

  // Recursive Item Builder
  let build-item-rows(item, index, is-sub-item: false) = {
    let rows = ()
    let bg = if calc.odd(index) { styles.color-row-odd } else {
      styles.color-row-even
    }
    let cell = table.cell.with(fill: bg, stroke: none)
    let cell-spacing = (inset: cell-inset, fill: bg)

    if item.at("is-group", default: false) {
      return do-render-group(ctx, item, total-cols, styles, cell-spacing)
    }

    let has-mods = (
      (
        item.at("has-discounts", default: false)
          or item.at("has-surcharge", default: false)
      )
        and layout.show-modifier
    )

    if layout.show-pos {
      rows.push(cell(if is-sub-item { "" } else { str(index) }))
    }
    rows.push(cell(do-render-title(
      ctx,
      item,
      layout,
      styles,
      is-sub-item: is-sub-item,
    )))

    for key in active-cols-keys {
      let content = if key == "quantity" {
        if layout.show-units { [#item.quantity #item.unit] } else {
          [#item.quantity]
        }
      } else if key == "unit-price" { item.price } else if key == "tax-rate" {
        [#item.tax.rate #item.tax.category]
      } else if key == "total-price" {
        if has-mods and "unmodified-total" in item {
          item.unmodified-total
        } else { item.total }
      }
      rows.push(cell(content))
    }

    if item.at("has-description", default: false) and layout.show-descriptions {
      rows += do-render-desc(
        ctx,
        item,
        layout,
        styles,
        (
          colspan: abs-desc-colspan,
          remaining: total-cols - desc-idx - abs-desc-colspan,
        ),
        cell-spacing,
      )
    }

    if has-mods {
      if item.at("has-discounts", default: false) {
        for d in item.discounts {
          rows += do-render-discount(
            ctx,
            d,
            layout,
            indices,
            styles,
            cell-spacing,
          )
        }
      }
      if item.at("has-surcharge", default: false) {
        for s in item.surcharge {
          rows += do-render-surcharge(
            ctx,
            s,
            layout,
            indices,
            styles,
            cell-spacing,
          )
        }
      }
    }

    if "sub-items" in item {
      for sub in item.sub-items {
        rows += build-item-rows(sub, index, is-sub-item: true)
      }
    }
    rows
  }

  let item-rows = ()
  let display-index = 1
  for item in data.items {
    item-rows += build-item-rows(item, display-index)
    if not item.at("is-group", default: false) { display-index += 1 }
  }

  table(
    columns: cols, stroke: none,
    align: (x, y) => {
      if x == 0 and layout.show-pos { center } else if x == desc-idx {
        left
      } else { right }
    },
    table-header, ..item-rows, ..table-footer,
    table.hline(stroke: styles.stroke-table-bottom)
  )
}
