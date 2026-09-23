// A LOOK is just a patch. `minimal` is a docs recipe, not a preset: it shows
// that a company can build its own look without any builder API (ported from
// the theming prototype's tests/looks.typ).
#import "/src/lib.typ": *
#let minimal-look = {
  import theme.custom: *
  sizes(title: 2em)
  title(arrange: "stack")
  strokes(regular: 0.5pt, thick: 1pt)
  items-table(zebra: (none, none))
  totals(width: 45%)
  area("footer", arrange: "row")
}
#let minimal = theme.classic.with(minimal-look, layout: theme.layout.a4-digital)
