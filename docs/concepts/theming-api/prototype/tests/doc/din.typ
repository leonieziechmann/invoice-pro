#import "prelude.typ": *
#let derive = theme.layout.derive
#let E = theme.layout
#let din-5008-a = (
  name: "din-5008-a",
  paper: "a4",
  margin: (top: 20mm, right: 20mm, bottom: auto, left: 25mm), // bottom: footer + descent + clearance
  marks: (fold: (87mm, 192mm), punch: 148.5mm, left: 5mm, length: 2.5mm), // stroke: hairline + text
  envelopes: E.folded(
    (87mm, 192mm),
    E.envelope.din-dl,
    E.envelope.din-c6-5,
    E.envelope.din-c5-a,
    E.envelope.din-c4-a,
  ),
  areas: (
    marks: (place: "background", parts: ("marks",)),
    letterhead: (
      left: 25mm,
      top: 8mm,
      width: 165mm,
      height: 19mm,
      stationery: true,
      par: (leading: 0.5em),
      parts: ("logo", "sender"),
      arrange: (columns: (1fr, auto), align: (left + horizon, right + top)),
    ),
    address: (
      left: 20mm,
      top: 27mm,
      width: 85mm,
      height: 45mm,
      inset: (left: 5mm, right: 5mm),
      par: (leading: 0.5em),
      parts: ("return-address", "recipient"),
      gap: 0pt,
      arrange: (rows: (17.7mm, 27.3mm), align: (left + bottom, left + top)),
    ),
    info: (
      left: 125mm,
      top: 32mm,
      width: 75mm,
      height: 40mm,
      parts: ("sender-details",),
    ),
    references: (place: "before", parts: ("references",)),
    title: (place: "before", parts: ("title",)),
    continuation: (place: "header", pages: "rest", parts: ("continuation",)),
    page-number: (place: "footer", parts: ("page-number",), align: right),
    footer: (
      place: "footer",
      stationery: true,
      text: (size: t => t.sizes.fine, fill: t => t.colors.text-muted),
      par: (leading: 0.45em),
      parts: ("company", "contact", "registration", "bank-account"),
      arrange: (columns: (1fr, 1fr, 1fr, 1fr)),
    ),
  ),
)
#let din-5008-b = derive(din-5008-a, (
  layout: (
    name: "din-5008-b",
    marks: (fold: (105mm, 210mm)),
    envelopes: E.folded(
      (105mm, 210mm),
      E.envelope.din-dl,
      E.envelope.din-c6-5,
      E.envelope.din-c5-b,
    ),
    areas: (
      letterhead: (height: 37mm),
      address: (top: 45mm),
      info: (top: 50mm),
    ),
  ),
))
// the listing equals the shipped data (after resolution)
#let R(l) = theme.resolve(theme.classic.with(layout: l)).layout
#assert(R(din-5008-a) == R(theme.layout.din-5008-a))
#assert(R(din-5008-b) == R(theme.layout.din-5008-b))
DIN LISTING MATCHES
