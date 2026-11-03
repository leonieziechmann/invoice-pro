// P7: the e-invoice "is it printed" checks stay active with the skeleton's
// static Wappen patch (`prints-of(theme).page-content` false), unlike a
// draw-time wrap of the logo part (true): design A's probe on the §4.7 rule.
#import "/repo/src/lib.typ": *
#import "/repo/src/theming/prints.typ": prints-of
#import "../examples/skeleton.typ": wappen
#let env = (kind: "invoice", lang: "de", region: "de", e-invoice: "en16931")
#let static-patch = theme.classic.with(theme.custom.logo(
  image: wappen,
  height: 18mm,
))
#let wrap-way = theme.classic.with(theme.custom.wrap("logo", (
  ctx,
  view,
  inner,
) => inner(ctx, view)))
#metadata((
  classic: prints-of(theme.resolve(theme.classic, env: env)).page-content,
  skeleton-patch: prints-of(theme.resolve(static-patch, env: env)).page-content,
  draw-time-wrap: prints-of(theme.resolve(wrap-way, env: env)).page-content,
)) <r>
