// The header row of a4-dense / us-letter-dense never collapses: recipient,
// references and title occupy disjoint boxes for EVERY preset (a title arranged as
// a row or a banner moves above the row; compact's stacked title keeps its column).
//   --input look=<preset> --input layout=a4-dense|us-letter-dense
#import "/tests/body.typ": *
#let look = sys.inputs.at("look", default: "classic")
#let lay = sys.inputs.at("layout", default: "a4-dense")
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
#show: invoice.with(
  theme: dictionary(theme)
    .at(look)
    .with(
      brand,
      probe("recipient"),
      probe("reference-list"),
      probe("title"),
      layout: dictionary(theme.layout).at(lay),
    ),
  locale: test-locale,
  ..party,
)
#body(n: 4)
#context {
  let boxes = query(<dense-box>).map(m => m.value)
  let names = boxes.map(b => b.name)
  for n in ("recipient", "reference-list", "title") {
    assert(
      n in names,
      message: look + " on " + lay + ": " + n + " not rendered",
    )
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
      message: look
        + " on "
        + lay
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
    assert(
      apart(a, b),
      message: look + " on " + lay + ": " + a.name + " overlaps " + b.name,
    )
  }
}
