#import "../../../utils/types.typ"

// --- Styling Callbacks (Return (content, content)) ---

#let render-subtotal(ctx, value, styles) = {
  // Should return a tuple (label, value) for the subtotal row.
  // The values should use the provided styles and ctx for localization.
  panic(
    "render-subtotal: Implement a function that returns a (label, value) content tuple for the subtotal.",
  )
}

#let render-total-net(ctx, value, styles) = {
  // Should return a tuple (label, value) for the intermediate net total.
  panic(
    "render-total-net: Implement a function that returns a (label, value) content tuple for the intermediate net total.",
  )
}

#let render-total-gross(ctx, value, styles) = {
  // Should return a tuple (label, value) for the grand gross total.
  panic(
    "render-total-gross: Implement a function that returns a (label, value) content tuple for the grand total.",
  )
}

#let render-discount(ctx, discount, styles) = {
  // Should return a tuple (label, value) for a single discount entry.
  panic(
    "render-discount: Implement a function that returns a (label, value) content tuple for a discount.",
  )
}

#let render-surcharge(ctx, surcharge, styles) = {
  // Should return a tuple (label, value) for a single surcharge entry.
  panic(
    "render-surcharge: Implement a function that returns a (label, value) content tuple for a surcharge.",
  )
}

#let render-tax(ctx, tax, styles) = {
  // Should return a tuple (label, value) for a single tax entry.
  panic(
    "render-tax: Implement a function that returns a (label, value) content tuple for a tax line.",
  )
}

// --- Structural Callbacks ---

/// Wrapper applied to every output of the styling functions
#let totals-cell-wrapper(ctx, content, styles) = {
  // Should wrap the raw content (label or value) in a container like table.cell.
  // This is the point where theme-specific cell styling (inset, fill, etc.) is applied.
  table.cell(content)
}

/// Assembles the wrapped elements into the final content
#let render-totals-body(ctx, data, styles, elements) = {
  // This function is the architect of the totals block.
  // It receives a dictionary 'elements' containing the already-wrapped cells:
  // elements: (subtotal: (c1, c2), modifiers: ((c1, c2), ...), taxes: (...), grand-total: (...))
  // It should arrange these cells into a grid, table, or custom layout.
  panic(
    "render-totals-body: Implement the assembly logic that arranges the wrapped elements into the final visual block.",
  )
}

// --- Main Component ---

#let render-totals(
  ctx,
  data,
  // Stylers
  render-subtotal: render-subtotal,
  render-total-net: render-total-net,
  render-total-gross: render-total-gross,
  render-discount: render-discount,
  render-surcharge: render-surcharge,
  render-tax: render-tax,
  // Wrapper & Builder
  totals-cell-wrapper: totals-cell-wrapper,
  render-totals-body: render-totals-body,
  // Standard styling parameters
  color-discount: rgb("b22222"),
  color-surcharge: rgb("333333"),
  color-vat-label: rgb("475569"),
  size-small: 0.85em,
  size-total: 1.2em,
  weight-bold: "bold",
  stroke-thin: 0.5pt,
  stroke-thick: 2pt,
  totals-width: 66%,
  totals-row-gutter: 0.6em,
  totals-col-gutter: 1em,
  totals-align: right,
) = {
  let styles = (
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
  )

  // Implementation logic for gathering and wrapping elements goes here.
  // The results should then be passed to render-totals-body.
  panic(
    "render-totals: Implement the collection and wrapping logic that prepares the elements for the builder.",
  )
}
