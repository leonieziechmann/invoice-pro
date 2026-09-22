// Contact sheet: page 1 of every preset on identical data (scripts/contact-sheet.sh
// renders the pages into out/cs first).  --input layout=auto|<name>  --input presets="a b .."
#let lay = sys.inputs.at("layout", default: "auto")
#let presets = sys.inputs.at("presets", default: "classic").split(" ")
#set page(
  width: 5 * 64mm + 6 * 5mm,
  height: auto,
  margin: 5mm,
  fill: rgb("#d9d9d9"),
)
#set text(font: "DejaVu Sans Mono", size: 9pt)
#grid(
  columns: (64mm,) * 5,
  column-gutter: 5mm,
  row-gutter: 5mm,
  ..presets.map(p => stack(
    spacing: 2mm,
    text(weight: "bold", p + " · " + lay),
    box(stroke: 0.4pt + black, image(
      "/out/cs/" + p + "-" + lay + "-1.png",
      width: 64mm,
    )),
  )),
)
