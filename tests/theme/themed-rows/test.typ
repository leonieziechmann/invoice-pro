/// [ppi: 60]

// themed(theme.custom.row(fill: ..)) fills every row inside the scope: items,
// groups and bundles, also within a group; the innermost scope wins. Items and
// bundles did not record the row style, so only groups were filled. The
// assertions check the entries the items table receives; the reference pins
// how they render.
#import "/tests/theme/body.typ": *

#let yellow = rgb("#fef3c7")
#let green = rgb("#dcfce7")
#let blue = rgb("#dbeafe")

// position -> expected fill of the item, group or bundle row
#let expected = (
  "1": none,
  "2": yellow,
  "3": yellow,
  "4": none,
  "5": none,
  "5.1": none,
  "5.2": green,
  "6": yellow,
  "6.1": yellow,
  "6.2": blue,
  "7": yellow,
  "8": none,
)

#let check-rows(ctx, view, inner) = {
  let fill(e) = {
    let style = e.at("style", default: none)
    if style == none { none } else { style.at("fill", default: none) }
  }
  let got = (:)
  for e in view.entries {
    if e.kind in ("item", "group-header") { got.insert(e.pos, fill(e)) }
  }
  assert.eq(got, expected)
  inner(ctx, view)
}

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.wrap("items-table", check-rows),
    layout: theme.layout.din-5008-a,
  ),
  locale: test-locale,
  ..party,
)

#line-items[
  #item([Konzeption], price: 1800)
  #themed(theme.custom.row(fill: yellow))[
    #item([Logo-Reinzeichnung], price: 650)
    #item([Geschäftsausstattung], price: 95, quantity: 4)
  ]
  #item([Druckabwicklung], price: 240)
  #group([Phase 2])[
    #item([Satz], price: 120)
    #themed(theme.custom.row(fill: green))[#item([Korrektur], price: 80)]
  ]
  #themed(theme.custom.row(fill: yellow))[
    #group([Phase 3 (optional)])[
      #item([Animation], price: 900)
      #themed(theme.custom.row(fill: blue))[#item([Ton], price: 300)]
    ]
    #bundle([Messepaket])[
      #item([Roll-up], price: 180)
      #item([Flyer], price: 0.5, quantity: 200)
    ]
  ]
  #bundle([Versand])[#item([Porto], price: 12)]
]
