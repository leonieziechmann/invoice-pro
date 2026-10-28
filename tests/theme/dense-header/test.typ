/// [ppi: 12]

// The header row of a4-dense / us-letter-dense never collapses (prototype
// tests/dense-header.typ, scripts/checks-fix-layouts.sh): recipient, references
// and title occupy disjoint boxes for EVERY preset (a title arranged as a row
// or a banner moves above the row; compact's stacked title keeps its column),
// and each part fits the cell it got. 10 presets x 2 dense layouts.
#import "/tests/theme/body.typ": *
#import "/tests/theme/harness.typ": case, close-cases, in-case

// each part reports its box: position of its cell + its size at the cell's width
#let probe(name) = theme.custom.wrap(name, (ctx, view, inner) => {
  let b = inner(ctx, view)
  layout(size => {
    let m = measure(b, width: size.width)
    context [#metadata((
      name: name,
      x: here().position().x,
      y: here().position().y,
      w: m.width,
      h: m.height,
      cell: size.width,
    )) <dense-box>]
    b
  })
})
#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
#let probes = ("recipient", "reference-list", "title").map(probe)
#let cases = (
  presets.map(p => ("a4-dense", "us-letter-dense").map(l => (p, l))).join()
)
#for (look, lay) in cases {
  case(
    look + " on " + lay,
    theme: preset-of(look).with(brand, ..probes, layout: layout-of(lay)),
    locale: test-locale,
    ..party,
    body(n: 4),
  )
}
#close-cases()

#context for (look, lay) in cases {
  let key = look + " on " + lay
  let boxes = in-case(key, <dense-box>)
  let names = boxes.map(b => b.name)
  for n in ("recipient", "reference-list", "title") {
    assert(n in names, message: key + ": " + n + " not rendered")
  }
  let first(n) = boxes.find(b => b.name == n)
  let (r, f, t) = (
    first("recipient"),
    first("reference-list"),
    first("title"),
  )
  // a part must fit the cell it got (a squeezed 1fr column overflows)
  for b in (r, f, t) {
    assert(
      b.w <= b.cell + 0.5pt and b.cell >= 30mm,
      message: key
        + ": "
        + b.name
        + " squeezed into a "
        + repr(b.cell)
        + " cell (needs "
        + repr(b.w)
        + ")",
    )
  }
  let apart(a, b) = (
    a.x + a.w <= b.x + 0.5pt
      or b.x + b.w <= a.x + 0.5pt
      or a.y + a.h <= b.y + 0.5pt
      or b.y + b.h <= a.y + 0.5pt
  )
  for (a, b) in ((r, f), (r, t), (f, t)) {
    assert(apart(a, b), message: key + ": " + a.name + " overlaps " + b.name)
  }
}
