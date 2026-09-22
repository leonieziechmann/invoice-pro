// api-tokens renders: page-number.format is ctx-first (ctx, current, total) and
// the default label is the locale string strings.document.page; the new tokens
// render on the embedded fonts (run with --ignore-system-fonts).
#import "/tests/body.typ": *
#let lang = sys.inputs.at("lang", default: "de")
#let fmt = sys.inputs.at("fmt", default: "auto")
#let loc = dictionary(locale).at(lang + "-de")
#let format = if fmt == "ctx" {
  (
    ctx,
    current,
    total,
  ) => [#metadata((lang: ctx.locale.strings.meta.lang, current: current, total: total))<pn> #current/#total]
} else { auto }
#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    page-number(from: 1, format: format)
    fonts(
      body: "Libertinus Serif",
      label: "DejaVu Sans Mono",
      numeric: "DejaVu Sans Mono",
    )
    spacing(leading: 0.8em)
    checks(min-contrast: 4.5, pairs: (
      ink: t => (t.colors.primary-text, t.colors.background),
    ))
  }),
  locale: loc,
  ..party,
)
#body(n: 30)
#if fmt == "ctx" {
  context {
    let q = query(<pn>).map(m => m.value)
    assert(
      q.len() >= 2,
      message: "page-number format was not called with ctx on every page: "
        + repr(q),
    )
    assert(
      q.all(v => v.lang == lang and v.total == q.first().total),
      message: repr(q),
    )
    assert(
      q.map(v => v.current) == range(1, q.first().total + 1),
      message: repr(q),
    )
  }
}
