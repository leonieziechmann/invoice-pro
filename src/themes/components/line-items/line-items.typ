#import "table.typ": render-table
#import "totals.typ": render-totals as generic-render-totals
#import "global-info.typ": render-global-info
#import "columns.typ": get-column-metadata

#let render-line-items(
  ctx,
  data,
  body,

  // General typography & colors
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

  // Strokes
  stroke-thin: 0.5pt,
  stroke-regular: 1pt,
  stroke-thick: 2pt,

  // Layout params
  cell-inset: (top: 0.125em, bottom: 0.125em),
  totals-width: 66%,
  totals-row-gutter: 0.6em,
  totals-col-gutter: 1em,
  totals-align: right,

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

  // Totals parameters
  totals-cell-wrapper: auto,
  render-totals-body: auto,
  render-subtotal: auto,
  render-total-net: auto,
  render-total-gross: auto,
  render-discount: auto,
  render-surcharge: auto,
  render-tax: auto,
) = {
  // Calculate Column Metadata
  let meta = get-column-metadata(data, column-order)

  render-table(
    ctx,
    data,
    color-subtitle: color-subtitle,
    color-desc: color-desc,
    color-row-odd: color-row-odd,
    color-row-even: color-row-even,
    color-discount: color-discount,
    color-surcharge: color-surcharge,
    size-subtitle: size-subtitle,
    size-small: size-small,
    weight-bold: weight-bold,
    stroke-thin: stroke-thin,
    stroke-regular: stroke-regular,
    cell-inset: cell-inset,

    column-order: column-order,
    render-description-cell: render-description-cell,
    render-discount-row: render-discount-row,
    render-surcharge-row: render-surcharge-row,
    render-subtotal-row: render-subtotal-row,

    header-bg: header-bg,
    header-color: header-color,
    header-repeat: header-repeat,
    stroke-header-top: stroke-header-top,
    stroke-header-bottom: stroke-header-bottom,
    stroke-table-bottom: stroke-table-bottom,
    render-header-cell: render-header-cell,
    render-table-header: render-table-header,
    render-table-footer: render-table-footer,

    tax-suffix-style: tax-suffix-style,
    render-tax-suffix: render-tax-suffix,
  )

  if data.layout-information.show-total {
    generic-render-totals(
      ctx,
      data,
      color-discount: color-discount,
      color-surcharge: color-surcharge,
      color-vat-label: color-vat-label,
      size-small: size-small,
      size-total: size-total,
      weight-bold: weight-bold,
      stroke-thin: stroke-thin,
      stroke-thick: stroke-thick,
      totals-width: totals-width,
      totals-row-gutter: totals-row-gutter,
      totals-col-gutter: totals-col-gutter,
      totals-align: totals-align,

      totals-cell-wrapper: if totals-cell-wrapper == auto { none } else {
        totals-cell-wrapper
      },
      render-totals-body: if render-totals-body == auto { none } else {
        render-totals-body
      },
      render-subtotal: if render-subtotal == auto { none } else {
        render-subtotal
      },
      render-total-net: if render-total-net == auto { none } else {
        render-total-net
      },
      render-total-gross: if render-total-gross == auto { none } else {
        render-total-gross
      },
      render-discount: if render-discount == auto { none } else {
        render-discount
      },
      render-surcharge: if render-surcharge == auto { none } else {
        render-surcharge
      },
      render-tax: if render-tax == auto { none } else { render-tax },
    )
  }

  render-global-info(
    ctx,
    data,
    color-desc: color-desc,
    size-small: size-small,
  )

  body
}
