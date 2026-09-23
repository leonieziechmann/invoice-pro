// The ctx-first page-number format is called on every page with the document's
// locale and the page counts of the invoice (prototype tests/api-tokens-render.typ,
// --input fmt=ctx). One invoice per document.
#import "/tests/theme/page-label.typ": *

#show: invoice.with(
  theme: page-theme(probe-format),
  locale: locale.de-de,
  ..party,
)
#body(n: 30)
#context {
  let q = query(<pn>).map(m => m.value)
  assert(
    q.len() >= 2,
    message: "page-number format was not called with ctx on every page: "
      + repr(q),
  )
  assert(
    q.all(v => v.lang == "de" and v.total == q.first().total),
    message: repr(q),
  )
  assert(
    q.map(v => v.current) == range(1, q.first().total + 1),
    message: repr(q),
  )
}
