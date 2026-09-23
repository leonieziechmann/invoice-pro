// page-number from: 2 leaves page 1 without the "Page 1 of 2" label; from: auto
// labels page 1 too (tests/theme/frame-view). Prototype render pair
// `page-from` (tests/api-frame/pairs.typ). One invoice per document.
#import "/tests/theme/body.typ": *

#let probe = theme.custom.wrap("page-number", (ctx, view, inner) => {
  let out = inner(ctx, view)
  [#metadata((page: view.page, label: out != none))<pn-from>]
  out
})
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(logo: logo-img),
    theme.custom.page-number(from: 2),
    probe,
    layout: theme.layout.din-5008-a,
  ),
  locale: test-locale,
  ..party,
)
#body(n: 30)
#context {
  let q = query(<pn-from>).map(m => m.value)
  let pages = counter(page).final().first()
  assert(pages >= 2, message: "the fixture needs two pages")
  assert.eq(q.map(x => x.page.current), range(1, pages + 1))
  assert(
    q.all(x => x.label == (x.page.current >= 2)),
    message: "from: 2 labels " + repr(q),
  )
}
