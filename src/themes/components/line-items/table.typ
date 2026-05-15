#import "../../../utils/types.typ"
#import "columns.typ": get-column-metadata

// --- Default Renderers (Content Only) ---

#let default-render-title(
  ctx,
  item,
  layout,
  styles,
) = {
  stack(
    dir: ttb,
    spacing: 0.4em,
    text(
      weight: styles.weight-bold,
      item.name,
    ),
    ..if item.has-date and layout.show-dates {
      (
        text(
          size: styles.size-small,
          style: "italic",
          item.date,
        ),
      )
    } else { () },
  )
}

#let default-render-description(
  ctx,
  item,
  layout,
  styles,
) = {
  set par(leading: 0.35em)
  set text(size: styles.size-small, fill: styles.color-desc)
  item.description
}

#let default-render-modifier(
  ctx,
  mod,
  styles,
  is-discount: true,
) = {
  let strings = ctx.locale.strings.line-items
  let color = if is-discount { styles.color-discount } else {
    styles.color-surcharge
  }
  let label-str = if is-discount { strings.discount } else { strings.surcharge }
  let sign = if is-discount { "−" } else { "+" }

  (
    label: text(
      size: styles.size-small,
      fill: color,
    )[↳ #label-str: #mod.name],
    percent: if mod.is-percent {
      text(fill: color)[(#sign #mod.display)]
    } else { [] },
    absolute: text(fill: color)[#sign #mod.absolute],
  )
}

#let default-render-group(ctx, item, styles) = {
  set text(weight: styles.weight-bold, fill: styles.color-subtitle)
  upper(item.name)
}

#let default-render-header(ctx, content, styles) = {
  set text(fill: styles.header-color)
  content
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

#let compute-description-colspan(
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
  // Content styling
  color-subtitle: luma(80),
  color-desc: luma(100),
  color-discount: rgb("b22222"),
  color-surcharge: rgb("333333"),
  size-subtitle: 0.85em,
  size-small: 0.85em,
  weight-bold: "bold",
  // Table styling
  color-row-odd: rgb("e2e8f0"),
  color-row-even: none,
  color-group-bg: auto,
  stroke-thin: 0.5pt,
  stroke-regular: 1pt,
  // New Spacing & Border System
  item-inset: (y: 0.25em),
  item-internal-inset: (y: 0.125em),
  item-stroke: none,
  // Legacy/Other styling
  cell-inset: (x: 0.4em),
  inset-group: (x: 0.5em, y: 0.6em),
  // Header styling
  header-bg: none,
  header-color: black,
  header-repeat: true,
  stroke-header-top: auto,
  stroke-header-bottom: auto,
  stroke-table-bottom: auto,
  header-cell-inset: (top: 0.5em, bottom: 0.5em),
  // Config
  column-order: ("quantity", "unit-price", "tax-rate", "total-price"),
  description-colspan: auto,
  tax-suffix-style: "newline",
  // Callbacks
  render-title: auto,
  render-description: auto,
  render-modifier: auto,
  render-group: auto,
  render-header: auto,
  render-table-footer: auto,
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
    item-inset: item-inset,
    item-internal-inset: item-internal-inset,
    item-stroke: item-stroke,
    cell-inset: cell-inset,
    inset-group: inset-group,
    header-cell-inset: header-cell-inset,
    color-row-odd: color-row-odd,
    color-row-even: color-row-even,
    color-group-bg: if color-group-bg == auto {
      color-row-odd.darken(5%)
    } else { color-group-bg },
  )

  set par(justify: false)

  // Pre-resolve callbacks
  let do-render-title = if render-title == auto { default-render-title } else {
    render-title
  }
  let do-render-desc = if render-description == auto {
    default-render-description
  } else { render-description }
  let do-render-header = if render-header == auto {
    default-render-header
  } else { render-header }
  let do-render-modifier = if render-modifier == auto {
    default-render-modifier
  } else { render-modifier }
  let do-render-group = if render-group == auto { default-render-group } else {
    render-group
  }

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

  let table-header-cells = raw-headers.map(h => table.cell(
    fill: styles.header-bg,
    inset: styles.header-cell-inset,
  )[#do-render-header(ctx, h, styles)])

  let table-header = table.header(
    repeat: styles.header-repeat,
    table.hline(stroke: styles.stroke-header-top),
    table.cell(colspan: total-cols, inset: 0pt, []),
    ..table-header-cells,
    table.cell(colspan: total-cols, inset: 0pt, []),
    table.hline(stroke: styles.stroke-header-bottom),
  )

  let table-footer = if render-table-footer != auto {
    render-table-footer(ctx, total-cols, styles)
  } else { () }

  let abs-description-colspan = compute-description-colspan(
    total-cols,
    desc-idx,
    active-cols-keys,
    description-colspan,
  )

  // Recursive Item Builder
  let build-item-rows(item, index, is-sub-item: false) = {
    let rows = ()
    let bg = if calc.odd(index) { styles.color-row-odd } else {
      styles.color-row-even
    }

    // 1. Resolve Strokes (Top, Bottom, Left, Right)
    let s = styles.item-stroke
    let (s-top, s-bot, s-left, s-right) = (none, none, none, none)
    if type(s) == dictionary {
      s-top = s.at("top", default: s.at("y", default: none))
      s-bot = s.at("bottom", default: s.at("y", default: none))
      s-left = s.at("left", default: s.at("x", default: none))
      s-right = s.at("right", default: s.at("x", default: none))
    } else {
      (s-top, s-bot, s-left, s-right) = (s, s, s, s)
    }

    // 2. Resolve Insets
    let i-in = styles.item-internal-inset
    let (in-top, in-bot) = (0pt, 0pt)
    if type(i-in) == dictionary {
      in-top = i-in.at("top", default: i-in.at("y", default: 0pt))
      in-bot = i-in.at("bottom", default: i-in.at("y", default: 0pt))
    } else {
      (in-top, in-bot) = (i-in, i-in)
    }

    let i-out = styles.item-inset
    let (out-top, out-bot) = (0pt, 0pt)
    if type(i-out) == dictionary {
      out-top = i-out.at("top", default: i-out.at("y", default: 0pt))
      out-bot = i-out.at("bottom", default: i-out.at("y", default: 0pt))
    } else {
      (out-top, out-bot) = (i-out, i-out)
    }

    let c-in = styles.cell-inset
    let (c-left, c-right) = (0pt, 0pt)
    if type(c-in) == dictionary {
      c-left = c-in.at("left", default: c-in.at("x", default: 0pt))
      c-right = c-in.at("right", default: c-in.at("x", default: 0pt))
    } else {
      (c-left, c-right) = (c-in, c-in)
    }

    // Group Row Logic
    if item.at("is-group", default: false) {
      return (
        table.cell(
          colspan: total-cols,
          fill: styles.color-group-bg,
          align: left,
          inset: styles.inset-group,
          stroke: (top: s-top, bottom: s-bot, left: s-left, right: s-right),
        )[#do-render-group(ctx, item, styles)],
      )
    }

    // Centralized cell generator for internal row elements
    let make-cell(content, col-idx, colspan: 1, align: auto) = {
      table.cell(
        colspan: colspan,
        align: align,
        fill: bg,
        inset: (top: in-top, bottom: in-bot, left: c-left, right: c-right),
        stroke: (
          left: if col-idx == 0 { s-left } else { none },
          right: if col-idx + colspan == total-cols { s-right } else { none },
          top: none,
          bottom: none,
        ),
      )[#content]
    }

    let has-mods = (
      (
        item.at("has-discounts", default: false)
          or item.at("has-surcharge", default: false)
      )
        and layout.show-modifier
    )

    // --- TOP CAP: Padding & Border ---
    if out-top != 0pt or s-top != none {
      rows.push(table.cell(
        colspan: total-cols,
        fill: bg,
        inset: (top: out-top, bottom: 0pt, left: 0pt, right: 0pt),
        stroke: (top: s-top, left: s-left, right: s-right, bottom: none),
        none,
      ))
    }

    // --- SECTION: MAIN ITEM ROW ---
    let col-tracker = 0
    if layout.show-pos {
      rows.push(make-cell(
        if is-sub-item { "" } else { str(index) },
        col-tracker,
        align: center,
      ))
      col-tracker += 1
    }

    rows.push(make-cell(
      do-render-title(ctx, item, layout, styles),
      col-tracker,
      align: left,
    ))
    col-tracker += 1

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
      rows.push(make-cell(content, col-tracker, align: right))
      col-tracker += 1
    }

    // --- SECTION: DESCRIPTION ROW ---
    if item.at("has-description", default: false) and layout.show-descriptions {
      let d-col-tracker = 0
      if layout.show-pos {
        rows.push(make-cell([], d-col-tracker))
        d-col-tracker += 1
      }
      rows.push(
        make-cell(
          do-render-desc(ctx, item, layout, styles),
          d-col-tracker,
          colspan: abs-description-colspan,
          align: left,
        ),
      )
      d-col-tracker += abs-description-colspan

      let remaining = total-cols - desc-idx - abs-description-colspan
      if remaining > 0 {
        rows.push(make-cell([], d-col-tracker, colspan: remaining))
      }
    }

    // --- SECTION: MODIFIER ROWS ---
    let build-modifier-row(mod, is-discount) = {
      let m-row = ()
      let m-col-tracker = 0

      if layout.show-pos {
        m-row.push(make-cell([], m-col-tracker))
        m-col-tracker += 1
      }

      let mod-content = do-render-modifier(
        ctx,
        mod,
        styles,
        is-discount: is-discount,
      )

      if indices.total != none {
        if indices.percent != none {
          let span1 = indices.percent - indices.desc
          m-row.push(make-cell(
            mod-content.label,
            m-col-tracker,
            colspan: span1,
            align: left,
          ))
          m-col-tracker += span1

          m-row.push(make-cell(
            mod-content.percent,
            m-col-tracker,
            align: right,
          ))
          m-col-tracker += 1

          m-row.push(make-cell(
            mod-content.absolute,
            m-col-tracker,
            align: right,
          ))
          m-col-tracker += 1
        } else {
          let span1 = indices.total - indices.desc
          m-row.push(make-cell(
            mod-content.label,
            m-col-tracker,
            colspan: span1,
            align: left,
          ))
          m-col-tracker += span1

          m-row.push(make-cell(
            [#mod-content.percent #mod-content.absolute],
            m-col-tracker,
            align: right,
          ))
          m-col-tracker += 1
        }
        let remaining = indices.total-count - m-col-tracker
        if remaining > 0 {
          m-row.push(make-cell([], m-col-tracker, colspan: remaining))
        }
      } else {
        let span1 = indices.total-count - indices.left - 1
        m-row.push(make-cell(
          mod-content.label,
          m-col-tracker,
          colspan: span1,
          align: left,
        ))
        m-col-tracker += span1

        m-row.push(make-cell(
          [#mod-content.percent #mod-content.absolute],
          m-col-tracker,
          align: right,
        ))
      }
      return m-row
    }

    if has-mods {
      if item.at("has-discounts", default: false) {
        for d in item.discounts { rows += build-modifier-row(d, true) }
      }
      if item.at("has-surcharge", default: false) {
        for s in item.surcharge { rows += build-modifier-row(s, false) }
      }

      // --- SECTION: SUBTOTAL ROW ---
      let sub-col-tracker = 0
      if layout.show-pos {
        rows.push(make-cell([], sub-col-tracker))
        sub-col-tracker += 1
      }

      // Label (aligned with description)
      let span1 = indices.total - indices.desc
      rows.push(make-cell(
        text(
          weight: styles.weight-bold,
          size: styles.size-subtitle,
        )[#li-str.subtotal],
        sub-col-tracker,
        colspan: span1,
        align: left,
      ))
      sub-col-tracker += span1

      // Total Value
      rows.push(make-cell(
        text(weight: styles.weight-bold)[#item.total],
        sub-col-tracker,
        align: right,
      ))
      sub-col-tracker += 1

      // Fill remaining
      let remaining = total-cols - sub-col-tracker
      if remaining > 0 {
        rows.push(make-cell([], sub-col-tracker, colspan: remaining))
      }
    }

    if "sub-items" in item {
      for sub in item.sub-items {
        rows += build-item-rows(sub, index, is-sub-item: true)
      }
    }

    // --- BOTTOM CAP: Padding & Border ---
    if out-bot != 0pt or s-bot != none {
      rows.push(table.cell(
        colspan: total-cols,
        fill: bg,
        inset: (top: 0pt, bottom: out-bot, left: 0pt, right: 0pt),
        stroke: (bottom: s-bot, left: s-left, right: s-right, top: none),
      )[#block(height: 0pt)])
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
    columns: cols,
    stroke: none,
    align: auto, // Let cells define alignment
    table-header,
    ..item-rows,
    ..table-footer,
    table.hline(stroke: styles.stroke-table-bottom)
  )
}
