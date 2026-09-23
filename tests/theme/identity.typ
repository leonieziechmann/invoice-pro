// The identity check (prototype tests/api-frame/identity.typ, concept §7): the
// invoice number and date must appear in the tagged first-page output. They
// are tagged with labelled metadata where they are typeset and checked after
// layout, so a title part may use layout(), measure() and context. Each case
// renders as a document of its own.
#import "/tests/theme/body.typ": *

// a poster title that measures its word and steps the size down until it fits
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
// number and date typeset inside context
#let in-context(
  ctx,
  view,
) = context [#view.document.number · #text(size: 1em.to-absolute() * 1.2, view.document.date.text)]
// the number is only MEASURED, never typeset
#let measured(
  ctx,
  view,
) = context [#view.document.title (#measure(view.document.number).width) #view.document.date.text]

/// An invoice whose title part is `title`, on a4-digital.
#let identity-invoice(title, validation: "draft") = invoice(
  theme: theme.classic.with(
    theme.custom.part("title", title),
    layout: theme.layout.a4-digital,
  ),
  locale: test-locale,
  validation: validation,
  ..party,
  body(),
)
