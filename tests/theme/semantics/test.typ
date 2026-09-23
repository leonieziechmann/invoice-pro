// Semantics of the theme engine (concept §4; prototype tests/semantics.typ):
// merge rules, anchor pairs, reset(), deep area merge, stubs, pages by place,
// the derivation resolver, callbacks, requirements by kind, contrast pairs.
#import "/src/lib.typ": *
#import theme.custom: *
#let R(th) = theme.resolve(th)
#let din = R(theme.classic)

// S1  `auto` in a patch is untouched, also in area(): no-op
#assert(
  R(theme.classic.with(area("address", left: auto, width: auto)))
    .layout
    .areas
    .address
    == din.layout.areas.address,
)
// S2  anchor pairs are exclusive: setting left clears right (the left-window recipe)
#let sn = R(theme.classic.with(
  layout: theme.layout.sn-010130-right,
  area("address", left: 22mm),
  area("info", right: 18mm),
))
#assert(
  sn.layout.areas.address.left == 22mm
    and sn.layout.areas.address.right == auto,
)
#assert(
  sn.layout.areas.info.right == 18mm and sn.layout.areas.info.left == auto,
)
#let snl = R(theme.classic.with(
  layout: theme.layout.sn-010130-right,
  area("address", left: 20mm, width: 72mm, height: 26mm),
  area("info", left: 125mm, width: 67mm),
))
#assert(
  R(theme.classic.with(layout: theme.layout.sn-010130-left))
    .layout
    .areas
    .address
    == snl.layout.areas.address,
)
// S3  reset() restores the schema default (auto = computed); "auto" in data files too
#assert(
  R(theme.classic.with(page(body-top: 60mm), page(body-top: reset())))
    .layout
    .body-top
    == auto,
)
#assert(
  R(theme.classic.with(items-table(header-text: red), items-table(
    header-text: reset(),
  )))
    .options
    .items-table
    .header-text
    == auto,
)
#assert(
  R(theme.classic.with(colors(primary: red), colors(primary: reset())))
    .tokens
    .colors
    .primary
    == rgb("#1f2937"),
)
#assert(
  R(theme.classic.with(from-data((
    options: (items-table: (header-text: "auto")),
  ))))
    .options
    .items-table
    .header-text
    == auto,
)
// S4  area fields merge deeply: inset folds as sides, text recurses
#assert(
  R(theme.classic.with(area("address", inset: (top: 2mm))))
    .layout
    .areas
    .address
    .inset
    == (top: 2mm, right: 5mm, bottom: 0pt, left: 5mm),
)
#let mo = R(theme.corporate.with(area("rail", text: (size: 9pt))))
#assert(
  mo.layout.areas.rail.text == (size: 9pt, fill: mo.tokens.colors.text-muted),
)
// S5  standard area names exist on every layout (stubs): portable patches
#let dig = R(theme.classic.with(layout: theme.layout.a4-digital, area(
  "info",
  fill: luma(240),
)))
#assert(dig.layout.areas.info.parts == ())
#assert(
  R(theme.classic.with(layout: theme.layout.a4-digital, area("info", none)))
    .layout
    .areas
    .info
    == none,
)
// removal is idempotent and sticky; a patch with `place` re-creates the area
#assert(
  R(theme.classic.with(area("stamp", none)))
    .layout
    .areas
    .at("stamp", default: 1)
    == 1,
)
#assert(
  R(theme.classic.with(area("info", none), area("info", top: 40mm)))
    .layout
    .areas
    .info
    == none,
)
#assert(
  R(theme.classic.with(area("info", none), area(
    "info",
    place: "before",
    parts: ("reference-list",),
  )))
    .layout
    .areas
    .info
    .place
    == "before",
)
// S6  pages default by place: running/layer areas on all pages, fixed/flow once
#let foot = R(theme.classic.with(area("legal", place: "footer", parts: ([x],))))
#assert(
  foot.layout.areas.legal.pages == "all"
    and foot.layout.areas.address.pages == "first",
)
// S7  resolver: acyclic chains of any depth settle; placeholders never leak
#let chain = R(theme.classic.with(colors(
  text: t => t.colors.text-muted,
  text-muted: t => t.colors.border,
  border: t => t.colors.background.darken(10%),
  background: t => t.colors.accent.lighten(95%),
  accent: t => t.colors.on-primary,
  on-primary: t => t.colors.primary,
)))
#assert(chain.tokens.colors.text == rgb("#1f2937").lighten(95%).darken(10%))
#assert(
  R(theme.classic.with(sizes(
    large: t => t.sizes.body * 1.2,
    title: t => t.sizes.body * (t.sizes.large / t.sizes.body),
  )))
    .tokens
    .sizes
    .title
    == 12pt,
)
// S8  a function-valued zebra (#33) is a callback, not a derivation
#let zb = R(theme.classic.with(items-table(zebra: i => if calc.even(i) {
  luma(240)
})))
#assert(type(zb.options.items-table.zebra) == function)
// S9  env.kind vocabulary; requirements are looked up by kind
#assert(
  din.requirements.parts == ("line-items", "items-table", "totals", "notes"),
)
// S10 contrast pairs include area band text on its fill
#let _ = R(theme.corporate.with(checks(min-contrast: 4.5)))
#let _ = R(theme.boxed.with(checks(min-contrast: 4.5)))
