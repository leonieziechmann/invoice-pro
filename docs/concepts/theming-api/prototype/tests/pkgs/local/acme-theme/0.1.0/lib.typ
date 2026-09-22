// @preview/acme-theme - NO invoice-pro import
#let sidebar-a5 = (
  name: "acme-sidebar-a5",
  paper: "a5",
  flipped: true,
  marks: none,
  margin: (top: 12mm, left: 72mm, right: 12mm), // bottom: computed from the footer
  areas: (
    rail: (
      place: "background",
      pages: "all",
      left: 0mm,
      top: 0mm,
      width: 60mm,
      height: 100%,
      stationery: true,
      fill: t => t.colors.primary,
      inset: 8mm,
      text: (fill: t => t.colors.on-primary, size: 8.5pt),
      parts: ("acme/rail", "sender"),
    ),
    title: (place: "before", parts: ("title",)),
    address: (place: "before", parts: ("recipient",)),
    page-number: (place: "footer", parts: ("page-number",), align: right),
    footer: (place: "footer", parts: ("registration",)),
  ),
)
#let rail(ctx, view) = text(size: 16pt, weight: "bold")[ACME]
#let patch = (
  parts: (
    "acme/rail": rail,
    signature: (
      "__invoice-pro-wrap__": (ctx, view, inner) => {
        inner(ctx, view)
        text(size: 7pt)[Digitally issued.]
      },
    ),
  ),
  tokens: (colors: (primary: rgb("#7c3aed")), sizes: (body: 9pt)),
  options: (items-table: (zebra: (none, none)), totals: (width: 60%)),
)
