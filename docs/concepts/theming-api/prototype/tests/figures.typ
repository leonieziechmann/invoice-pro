// Builds the concept figures from rendered pages (scripts/figures.sh).
#let fig = sys.inputs.at("fig", default: "matrix")
#set page(width: auto, height: auto, margin: 8pt, fill: white)
#set text(font: "Liberation Sans", size: 8pt)
#let pg(p, w: 110pt) = box(stroke: 0.4pt + luma(170), image(
  "/out/fig/" + p,
  width: w,
))
#let cap(t) = text(weight: "bold", t)
#if fig == "matrix" {
  let looks = ("classic", "corporate", "minimal", "plain")
  let lays = (
    "din-5008-a",
    "din-5008-b",
    "us-letter-10",
    "a4-digital",
    "sn-010130-right",
    "plain",
  )
  grid(
    columns: 1 + lays.len(), gutter: 5pt, align: center + horizon,
    [], ..lays.map(l => cap(raw(l))),
    ..looks
      .map(k => (
        rotate(-90deg, reflow: true, cap(raw(k))),
        ..lays.map(l => pg("m-" + k + "-" + l + "-1.png", w: 92pt)),
      ))
      .flatten()
  )
} else if fig == "stationery" {
  grid(
    columns: 3, gutter: 8pt, align: center,
    ..("print", "pdf", "einvoice").map(m => cap(raw("output=" + m))),
    ..("print", "pdf", "einvoice").map(m => stack(
      dir: ltr,
      spacing: 3pt,
      pg("p2-" + m + "-1.png"),
      pg("p2-" + m + "-2.png"),
    ))
  )
} else if fig == "swiss" {
  grid(
    columns: 3,
    gutter: 6pt,
    align: center,
    cap[page 1 (window left)],
    cap[page 2],
    cap[page 3: reserved zone + relocated footer],

    pg("p3-1.png", w: 150pt),
    pg("p3-2.png", w: 150pt),
    pg("p3-3.png", w: 150pt),
  )
} else if fig == "any-format" {
  grid(
    columns: 2,
    gutter: 8pt,
    align: center + top,
    cap[third-party A5 landscape layout (zero imports)],
    cap[80 mm thermal roll (height: auto)],

    pg("p9-1.png", w: 300pt), pg("rc-1.png", w: 90pt),
  )
} else if fig == "parts" {
  grid(
    columns: 2,
    gutter: 8pt,
    align: center,
    cap[P6: corporate on DIN B, wrap + replace],
    cap[(10): scoped row fill and scoped seed],

    pg("p6-1.png", w: 200pt), pg("p10-1.png", w: 200pt),
  )
}
