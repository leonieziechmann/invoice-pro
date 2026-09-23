/// [ppi: 60]

// Knobs that only paint, in one render (prototype render pairs `radius` and
// `rule` in tests/api-frame/pairs.typ; api-body cases `style`, `rule` and
// `inset` in tests/api-body.typ): a rounded address fill, a red title rule,
// the items-table header style, a hairline row rule, a row inset, and a dark,
// wide totals block. The prototype asserted that each knob changes the render;
// this reference pins how they render.
#import "/tests/theme/body.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    {
      import theme.custom: *
      brand(logo: logo-img)
      area("address", fill: luma(230), radius: 3mm)
      area("title", rule: (side: bottom, gap: 2mm, stroke: 1pt + red))
      items-table(
        header-style: (
          fill: rgb("#b00020"),
          style: "italic",
          size: t => t.sizes.body * 1.1,
        ),
        row-rule: t => t.strokes.hairline + t.colors.border,
        row-inset: 6pt,
      )
      totals(fill: rgb("#1f2937"), min-width: 120mm, width: 30%)
    },
    layout: theme.layout.din-5008-a,
  ),
  locale: test-locale,
  ..party,
)
#body(n: 4)
