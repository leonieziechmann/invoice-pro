#import "../../../utils/types.typ"

#let render-totals(
  ctx,
  data,

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
) = {
  types.require(color-discount, "render-totals::color-discount", color, none)
  types.require(color-surcharge, "render-totals::color-surcharge", color, none)
  types.require(color-vat-label, "render-totals::color-vat-label", color, none)

  types.require(weight-bold, "render-totals::weight-bold", str, int)

  types.require(stroke-thin, "render-totals::stroke-thin", stroke, length, none)
  types.require(
    stroke-thick,
    "render-totals::stroke-thick",
    stroke,
    length,
    none,
  )

  let sum-str = ctx.locale.strings.summary
  let li-str = ctx.locale.strings.line-items

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
              [#sum-str.sum (#li-str.gross):],
              data.unmodified-total.gross,
            )
          } else { () },

          ..data
            .discounts
            .map(d => (
              text(
                fill: color-discount,
                size-small,
              )[#li-str.discount: #d.name],
              text(
                fill: color-discount,
              )[#if d.is-percent [(− #d.display) #h(.5em)] − #d.absolute],
            ))
            .flatten(),

          ..data
            .surcharges
            .map(s => (
              text(
                fill: color-surcharge,
                size-small,
              )[#li-str.surcharge: #s.name],
              text(
                fill: color-surcharge,
              )[#if s.is-percent [(\+ #s.display) #h(.5em)] \+ #s.absolute],
            ))
            .flatten(),

          grid.hline(stroke: stroke-thick),

          pad(top: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[#sum-str.total:]),
          pad(top: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[#data.total.gross]),

          grid.hline(stroke: stroke-thick), [], [],

          ..data
            .taxes
            .map(t => (
              text(
                fill: color-vat-label,
              )[#sum-str.including #sum-str.vat-tax #t.rate (#t.category):],
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

          [#sum-str.sum (#li-str.net):], data.unmodified-total.net,

          ..data
            .discounts
            .map(d => (
              text(
                fill: color-discount,
                size-small,
              )[#li-str.discount: #d.name],
              text(
                fill: color-discount,
              )[#if d.is-percent [(− #d.display) #h(.5em)] − #d.absolute],
            ))
            .flatten(),

          ..data
            .surcharges
            .map(s => (
              text(
                fill: color-surcharge,
                size-small,
              )[#li-str.surcharge: #s.name],
              text(
                fill: color-surcharge,
              )[#if s.is-percent [(+ #s.display) #h(.5em)] \+ #s.absolute],
            ))
            .flatten(),

          ..if data.discounts.len() > 0 or data.surcharges.len() > 0 {
            (
              text(weight: weight-bold)[#li-str.total #li-str.net:],
              text(weight: weight-bold)[#data.total.net],
            )
          } else { () },

          grid.hline(stroke: stroke-thin),

          pad(top: 0.3em)[], pad(top: 0.3em)[],

          ..data
            .taxes
            .map(t => (
              text(
                fill: color-vat-label,
              )[#sum-str.excluding #sum-str.vat-tax #t.rate (#t.category):],
              text(fill: black)[#t.amount],
            ))
            .flatten(),

          pad(y: -.5em)[], pad(y: -.5em)[],
          pad(bottom: 0.3em)[], pad(bottom: 0.3em)[],

          grid.hline(stroke: stroke-thick),

          pad(y: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[#sum-str.total:]),
          pad(y: 0.5em, text(
            weight: weight-bold,
            size: size-total,
          )[#data.total.gross]),

          grid.hline(stroke: stroke-thick),
        )
      }
    })
  ]
}
