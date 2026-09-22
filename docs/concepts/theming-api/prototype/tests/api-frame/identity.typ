// Identity check without repr() (gap 8): number and date are tagged with labelled
// metadata where they are typeset and checked after layout, so a title part may use
// layout(), measure() and context. Run under strict.
//   --input mode=responsive  a poster title that measures its word and steps the size
//                            down until it fits (must pass)
//   --input mode=context     number and date typeset inside context (must pass)
//   --input mode=measured    the number is only MEASURED, never typeset (must panic)
//   --input mode=date        the date is missing from the title (must panic, BT-2)
#import "/tests/body.typ": *
#let mode = sys.inputs.at("mode", default: "responsive")

#let responsive(ctx, view) = layout(size => {
  let d = view.document
  let s = 60pt
  let word = upper(d.title + "abschlagsrechnung") // a long single word
  while (
    measure(text(size: s, weight: "bold", word)).width > size.width * 0.62
      and s > 12pt
  ) { s -= 2pt }
  grid(
    columns: (1fr, auto),
    align: (left + bottom, right + bottom),
    text(size: s, weight: "bold", word), [#d.number \ #d.date.text],
  )
})
#let in-context(
  ctx,
  view,
) = context [#view.document.number · #text(size: 1em.to-absolute() * 1.2, view.document.date.text)]
#let measured(
  ctx,
  view,
) = context [#view.document.title (#measure(view.document.number).width) #view.document.date.text]
#let no-date(ctx, view) = [#view.document.title #view.document.number]
#let title = (
  responsive: responsive,
  "context": in-context,
  measured: measured,
  date: no-date,
).at(mode)

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.part("title", title),
    layout: theme.layout.a4-digital,
  ),
  locale: test-locale,
  ..party,
)
#body()
