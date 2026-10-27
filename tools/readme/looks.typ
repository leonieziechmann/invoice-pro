// The ten looks of the README (scripts/readme-images): the example invoice
// in every preset, named, on a rounded card. The pages come from
// build/readme/pages (tools/readme/invoice.typ).
#set page(width: auto, height: auto, margin: 0pt, fill: none)
#set text(font: ("DejaVu Sans Mono",), size: 13pt, fill: rgb("#0f172a"))

#let presets = (
  "classic",
  "plain",
  "corporate",
  "elegant",
  "prestige",
  "bold",
  "technical",
  "soft",
  "compact",
  "boxed",
)
#let page-w = 150pt

#let look(name) = stack(
  spacing: 9pt,
  box({
    for (k, a) in ((6pt, 6%), (3pt, 9%)) {
      place(dy: k, rect(
        width: page-w,
        height: page-w * 297 / 210,
        radius: 2pt,
        fill: rgb(15, 23, 42).transparentize(100% - a),
      ))
    }
    image("/build/readme/pages/" + name + "-1.png", width: page-w)
  }),
  align(center, raw("theme." + name)),
)

#box(
  radius: 14pt,
  clip: true,
  fill: gradient.linear(rgb("#eef6f4"), rgb("#e2e9f0"), angle: 90deg),
  inset: (x: 22pt, top: 22pt, bottom: 18pt),
  grid(
    columns: 5,
    column-gutter: 16pt,
    row-gutter: 18pt,
    ..presets.map(look),
  ),
)
