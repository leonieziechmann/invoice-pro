// page-number.format is ctx-first, (ctx, current, total) => content, and the
// default label is the locale string strings.document.page (prototype
// tests/api-tokens-render.typ); the new font roles render on the embedded fonts.
#import "/tests/theme/body.typ": *

/// A format callback that reports its arguments as <pn> metadata.
#let probe-format(ctx, current, total) = [#metadata((
    lang: ctx.locale.strings.meta.lang,
    current: current,
    total: total,
  ))<pn> #current/#total]

/// The api-tokens-render theme: page numbers from page 1, the given format.
#let page-theme(format) = theme.classic.with({
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
})
