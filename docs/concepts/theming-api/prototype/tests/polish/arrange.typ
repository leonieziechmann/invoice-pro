// The serif letterhead arrangement fits its box and never squeezes the logo
// column (a squeezed column cut prestige's on-dark plate into white bars on
// sn-010130-right). Boxes: SN 010130 (80 x 30 mm, inset 6/2.5 mm), DIN 5008
// form A (19 mm high), a band and a flowing (auto-height) area.
#import "/src/theming/looks/serif.typ": letterhead-arrange

#let plate(w, h) = box(width: w, height: h, fill: white, inset: 1.4mm, box(
  width: 100%,
  height: 100%,
  fill: rgb("#0f766e"),
))
#let words(name) = block(align(center, stack(
  spacing: 1mm,
  text(size: 13.5pt, tracking: 0.06em, upper(name)),
  line(length: 18mm),
  text(size: 7.8pt)[Hafenstraße 12 · 20457 Hamburg],
)))
#let boxes = (
  (width: 68mm, height: 25mm), // sn-010130-right letterhead, inner box
  (width: 170mm, height: 14mm), // din-5008-a, inner box
  (width: 186mm, height: 35mm), // a4-band
  (width: 68mm, height: auto), // flowing
)
#let marks = (plate(37mm, 14mm), plate(20mm, 20mm), plate(60mm, 12mm))
#let names = ("Atelier Nord GmbH", "Grand Hotel Bellevue Palace Bern AG")

#context for a in boxes {
  for m in marks {
    for n in names {
      let cells = (("logo", m), ("sender", words(n)))
      let out = letterhead-arrange(none, cells, a)
      let got = measure(block(width: a.width, out))
      let natural = measure(out, width: a.width)
      // fits the width (no overflow into the margin) ...
      assert(
        natural.width <= a.width + 0.01mm,
        message: repr(a) + " " + n + ": width " + repr(natural.width),
      )
      // ... a logo beside the words gets a column as wide as the logo itself
      let g = if out.func() == align { out.body } else { out }
      if g.func() == grid {
        let first = g.children.first()
        let cell = if first.func() == grid.cell { first.body } else { first }
        assert(
          type(g.columns) == array
            and type(g.columns.first()) in (length, relative)
            and g.columns.first().ratio == 0%,
          message: repr(a)
            + " "
            + n
            + ": logo column is not fixed "
            + repr(g.columns),
        )
        assert(
          g.columns.first().length >= measure(cell).width - 0.01mm,
          message: repr(a) + " " + n + ": logo column squeezed",
        )
      }
      // ... and the height of a fixed box, when that is at all possible
      if a.height != auto {
        assert(
          got.height <= a.height + 0.01mm,
          message: repr(a) + " " + n + ": height " + repr(got.height),
        )
      }
    }
  }
}
// without a logo the words are simply centred
#context assert(
  measure(letterhead-arrange(
    none,
    (("sender", words("X")),),
    boxes.first(),
  )).width
    > 0pt,
)
ok
