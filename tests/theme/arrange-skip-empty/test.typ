// `skip-empty: true` in a grid arrangement: an empty cell gives up its
// column, with the column's width and alignment, so the other cells share the
// area (the legal footer of a4-digital without `extra`). Without it, the empty
// cell keeps its column.
#import "/tests/theme/body.typ": *
#import theme.custom: *

// The tag sits inside the box: a tag in front of it would report the start of
// the line, before the cell's alignment moves the box.
#let mark(case, cell) = box(width: 5mm, height: 3mm, fill: black)[#metadata((
  case: case,
  cell: cell,
))<cell>]
// a function cell that renders nothing
#let nothing = (ctx, view) => none

// The info area of din-5008-a, 75 mm wide, with four cells: a, an empty one,
// c and d (aligned right).
#let probe(case, skip) = theme.classic.with(
  area(
    "info",
    parts: (mark(case, "a"), nothing, mark(case, "c"), mark(case, "d")),
    arrange: (
      columns: (1fr, 2fr, 1fr, 1fr),
      align: (left, left, left, right),
      skip-empty: skip,
    ),
    gap: 0pt,
  ),
  layout: theme.layout.din-5008-a,
)
#for (case, skip) in (("skip", true), ("keep", false)) {
  invoice(theme: probe(case, skip), locale: test-locale, ..party)[#body()]
}

#context {
  let x = (:)
  for m in query(<cell>) {
    x.insert(m.value.case + "/" + m.value.cell, m.location().position().x)
  }
  // d is aligned right in the last column, so it ends at the area's edge
  let width(case) = x.at(case + "/d") + 5mm - x.at(case + "/a")
  let at(case, cell) = {
    let start = x.at(case + "/a")
    (x.at(case + "/" + cell) - start) / width(case)
  }
  // keep: 1fr 2fr 1fr 1fr, c starts at 3/5 of the area
  assert(
    calc.abs(at("keep", "c") - 3 / 5) < 0.01,
    message: "without skip-empty, c starts at " + repr(at("keep", "c")),
  )
  // skip: 1fr 1fr 1fr, c starts at 1/3; d keeps its alignment (right), so the
  // cells span the same width
  assert(
    calc.abs(at("skip", "c") - 1 / 3) < 0.01,
    message: "with skip-empty, c starts at " + repr(at("skip", "c")),
  )
  assert(
    calc.abs((width("skip") - width("keep")) / 1mm) < 0.1,
    message: "with skip-empty, d is no longer aligned right",
  )
}
