// API branch "api-tokens": new frozen tokens, declared contrast pairs, theme label
// strings, per-part option metadata. Pure API asserts; compile-fail probes and
// renders live in scripts/checks-api-tokens.sh.
#import "/src/lib.typ": *
#import "/src/theming/schema.typ": (
  check-schema, composite-parts, non-part-options, option-schema, part-options,
  token-schema,
)
#import "/src/theming/color.typ": contrast
#import "/src/locale/lang/lang.typ" as langs
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region

#let R(..p) = theme.resolve(theme.classic.with(..p), validation: "draft")

// --- 1. new frozen tokens: schema, defaults, derivations ------------------------------
#assert(
  token-schema.colors.keys().slice(0, 5)
    == ("primary", "on-primary", "primary-text", "accent", "accent-text"),
)
#assert(
  "radii" in token-schema and token-schema.radii.keys() == ("small", "medium"),
)
#let d = R()
#assert(
  d.tokens.fonts.label == d.tokens.fonts.body
    and d.tokens.fonts.numeric == d.tokens.fonts.body,
)
#assert(d.tokens.radii == (small: 2pt, medium: 4pt))
#assert(d.tokens.spacing.leading == 0.65em)
// the default seed is already legible: primary-text == primary (as rgb)
#assert(d.tokens.colors.primary-text == d.tokens.colors.primary)
#assert(d.tokens.colors.accent-text == d.tokens.colors.primary-text) // accent derives from primary
// a light brand colour is darkened for text; the fill role keeps the seed
#let y = R(theme.custom.colors(primary: rgb("#fbbf24")))
#assert(y.tokens.colors.primary == rgb("#fbbf24"))
#assert(contrast(y.tokens.colors.primary-text, white) >= 4.5, message: repr(
  y.tokens.colors.primary-text,
))
#assert(contrast(y.tokens.colors.primary, white) < 4.5)
// on a dark page the text roles are lightened instead
#let dk = R(theme.custom.colors(
  primary: rgb("#1e3a8a"),
  accent: rgb("#7c2d12"),
  background: rgb("#111111"),
  text: white,
  text-muted: luma(200),
))
#assert(contrast(dk.tokens.colors.primary-text, rgb("#111111")) >= 4.5)
#assert(contrast(dk.tokens.colors.accent-text, rgb("#111111")) >= 4.5)
#assert(dk.tokens.colors.accent-text != dk.tokens.colors.primary-text) // follows accent, not primary
// CMYK seeds: derivations are RGB, so only the seed is reported (PDF/A lint)
#assert(
  R(theme.custom.colors(primary: cmyk(80%, 20%, 0%, 30%)))
    .tokens
    .colors
    .primary-text
    .space()
    == rgb,
)
// label / numeric follow the body font (brand) unless set
#let b = R(theme.custom.brand(font: "Libertinus Serif"))
#assert(
  b.tokens.fonts.label == "Libertinus Serif"
    and b.tokens.fonts.numeric == "Libertinus Serif",
)
#let m = R(theme.custom.fonts(label: "DejaVu Sans Mono"))
#assert(
  m.tokens.fonts.label == "DejaVu Sans Mono"
    and m.tokens.fonts.numeric == m.tokens.fonts.body,
)
#let m2 = R(
  theme.custom.fonts(numeric: ("DejaVu Sans Mono",)),
  theme.custom.brand(font: "Libertinus Serif"),
)
#assert(
  m2.tokens.fonts.numeric == ("DejaVu Sans Mono",)
    and m2.tokens.fonts.label == "Libertinus Serif",
)
// helpers
#let r = R({
  import theme.custom: *
  radii(small: 1pt, medium: 6pt)
  spacing(leading: 0.8em)
  colors(primary-text: rgb("#0b3d91"), accent-text: rgb("#7c2d12"))
})
#assert(
  r.tokens.radii == (small: 1pt, medium: 6pt)
    and r.tokens.spacing.leading == 0.8em,
)
#assert(
  r.tokens.colors.primary-text == rgb("#0b3d91")
    and r.tokens.colors.accent-text == rgb("#7c2d12"),
)
// radii derive like every token
#assert(
  R(theme.custom.radii(medium: t => t.radii.small * 3)).tokens.radii.medium
    == 6pt,
)
// from-data: the new tokens come from a file like the others
#let f = R(theme.custom.from-data((
  tokens: (
    fonts: (label: "DejaVu Sans Mono", numeric: "Libertinus Serif"),
    colors: (primary-text: "#123456"),
    radii: (small: "3pt", medium: "5mm"),
    spacing: (leading: "0.7em"),
  ),
)))
#assert(
  f.tokens.fonts.label == "DejaVu Sans Mono"
    and f.tokens.fonts.numeric == "Libertinus Serif",
)
#assert(
  f.tokens.colors.primary-text == rgb("#123456")
    and f.tokens.colors.accent-text == d.tokens.colors.accent-text,
)
#assert(
  f.tokens.radii == (small: 3pt, medium: 5mm)
    and f.tokens.spacing.leading == 0.7em,
)
// brand() stays the five-minute path (label/numeric voices are look decisions)
#assert(
  theme
    .custom
    .brand(font: "X")
    .find(p => "fonts" in p.at("tokens", default: (:)))
    .tokens
    .fonts
    .keys()
    == ("body",),
)

// --- 2. checks.pairs ------------------------------------------------------------------
#assert(check-schema.keys() == ("min-contrast", "pairs"))
#let disc = theme.custom.checks(pairs: (
  disc: t => (t.colors.tint, t.colors.background),
))
#let low = R(disc, theme.custom.checks(min-contrast: 4.5))
#let hit = low.issues.filter(i => i.id == "lint/contrast-checks::pairs::disc")
#assert(hit.len() == 1, message: repr(low.issues.map(i => i.id)))
#assert(
  hit
    .first()
    .message
    .starts-with(
      "theme: checks::pairs::disc (#e2e8f0 on #ffffff) has contrast ",
    ),
  message: hit.first().message,
)
#assert(hit.first().message.ends-with("below checks.min-contrast 4.5:1"))
// without min-contrast nothing is checked
#assert(
  R(disc).issues.filter(i => i.id.starts-with("lint/contrast")).len() == 0,
)
// a legible pair passes; pairs merge by name (look + user), `none` drops one, same name replaces
#let ok-pair = theme.custom.checks(pairs: (
  ink: t => (t.colors.primary-text, t.colors.background),
))
#assert(
  R(ok-pair, theme.custom.checks(min-contrast: 4.5))
    .issues
    .filter(i => i.id.starts-with("lint/contrast"))
    .len()
    == 0,
)
#let both = R(disc, ok-pair, theme.custom.checks(min-contrast: 4.5))
#assert(both.checks.pairs.keys() == ("disc", "ink"))
#let dropped = R(disc, ok-pair, theme.custom.checks(min-contrast: 4.5, pairs: (
  disc: none,
)))
#assert(
  dropped.issues.filter(i => i.id.starts-with("lint/contrast")).len() == 0,
)
#let replaced = R(disc, theme.custom.checks(min-contrast: 4.5, pairs: (
  disc: t => (black, t.colors.tint),
)))
#assert(
  replaced.issues.filter(i => i.id.starts-with("lint/contrast")).len() == 0,
)
// a literal pair (no derivation) works too
#assert(
  R(theme.custom.checks(min-contrast: 3, pairs: (lit: (luma(200), white))))
    .issues
    .any(i => i.id == "lint/contrast-checks::pairs::lit"),
)
// reset() restores the empty map
#assert(
  R(disc, theme.custom.checks(pairs: theme.custom.reset())).checks.pairs == (:),
)
// declared pairs live in a look too (preset-level declaration), and in themed scopes
#let look = theme.classic.with(disc)
#assert(
  theme
    .resolve(
      look.with(theme.custom.checks(min-contrast: 4.5)),
      validation: none,
    )
    .issues
    .any(i => i.id == "lint/contrast-checks::pairs::disc"),
)

// --- 3. locale strings for theme labels -----------------------------------------------
#let L(lang, ..patches) = dictionary(locale).at(lang + "-de").with(..patches)(
  base-language,
  base-region,
)
#let plain(c) = if type(c) == str { c } else if c.has("text") {
  c.text
} else if c.has("children") { c.children.map(plain).join() } else if (
  c.func() == [ ].func()
) { " " } else { repr(c) }
#let expect = (
  de: ([Seite 2 von 3], "Bankverbindung", "Art.-Nr."),
  en: ([Page 2 of 3], "Bank details", "Item No."),
  fr: ([Page 2 sur 3], "Coordonnées bancaires", "Réf."),
  it: ([Pagina 2 di 3], "Coordinate bancarie", "Cod. art."),
  es: ([Página 2 de 3], "Datos bancarios", "Ref."),
)
#for (lang, (page, bank, id)) in expect {
  let s = L(lang).strings
  assert(
    plain((s.document.page)(2, 3)) == plain(page),
    message: lang + ": " + repr((s.document.page)(2, 3)),
  )
  assert(
    s.sections.bank-details == bank and s.line-items.item-id == id,
    message: lang,
  )
  assert(
    type((s.document.continued-on)(4)) == content
      and s.signature.thanks != ""
      and s.line-items.unit != "",
  )
}
// every language file defines every key of the new groups (no silent English fallback)
#for lang in ("de", "en", "fr", "it", "es") {
  let s = dictionary(langs).at(lang)
  assert(
    s.sections.keys() == base-language.sections.keys(),
    message: lang + " sections",
  )
  for k in ("page", "continued-on") {
    assert(k in s.document, message: lang + " document::" + k)
  }
  for k in ("item-id", "unit") {
    assert(k in s.line-items, message: lang + " line-items::" + k)
  }
  assert("thanks" in s.signature, message: lang + " signature::thanks")
}
// the address and due-date labels are reused, not duplicated
#assert(
  "recipient" not in base-language.sections
    and "due-date" not in base-language.sections,
)
// overrides go through locale.custom (labels are locale strings, not theme values)
#let o = L(
  "de",
  locale.custom.document(page: (c, t) => [#c/#t]),
  locale.custom.sections(payment: "Zahlungsinfo"),
  locale.custom.line-items(item-id: "Artikel"),
  locale.custom.signature(thanks: "Danke!"),
)
#assert(
  plain((o.strings.document.page)(1, 2)) == "1/2"
    and o.strings.sections.payment == "Zahlungsinfo",
)
#assert(
  o.strings.sections.bank-details == "Bankverbindung"
    and o.strings.line-items.item-id == "Artikel",
)
#assert(
  o.strings.signature.thanks == "Danke!"
    and o.strings.signature.closing == "Mit freundlichen Grüßen,",
)

// --- 4. options honoured by built-in renderers ----------------------------------------
// every option group is read by a built-in part or listed as non-part; readers are built-in parts
#for g in option-schema.keys() {
  assert(
    g in part-options or g in non-part-options,
    message: "option group " + g + " has no reader",
  )
}
#for (g, readers) in part-options {
  assert(g in option-schema, message: g)
  for p in readers {
    assert(p in dictionary(theme.parts), message: g + " reader " + p)
  }
}
#for (child, parent) in composite-parts {
  assert(child in dictionary(theme.parts) and parent in dictionary(theme.parts))
}
#assert(d.base.part-options == part-options) // introspectable from any resolved theme
#assert(d.unread-options == ())
// replaced reader -> unread; wrapped reader -> still read; re-setting the built-in -> read
#let fake-title = (
  ctx,
  view,
) => [#view.document.subject #view.document.number #view.document.date.text]
#assert(
  R(theme.custom.title(arrange: "stack"), theme.custom.part(
    "title",
    fake-title,
  )).unread-options
    == ("title",),
)
#assert(
  R(theme.custom.title(arrange: "stack"), theme.custom.wrap("title", (
    ctx,
    view,
    inner,
  ) => inner(ctx, view))).unread-options
    == (),
)
#assert(
  R(
    theme.custom.title(arrange: "stack"),
    theme.custom.part("title", fake-title),
    theme.custom.part("title", theme.parts.title),
  ).unread-options
    == (),
)
// unchanged options are never reported, even when their reader is replaced
#assert(R(theme.custom.part("title", fake-title)).unread-options == ())
// composite: replacing line-items leaves items-table, totals and line-items options unread
#let li = R(
  theme.custom.items-table(zebra: (none, none)),
  theme.custom.totals(width: 50%),
  theme.custom.line-items(discount-color: blue),
  theme.custom.part("line-items", (ctx, view) => [x]),
)
#assert(
  li.unread-options == ("line-items", "items-table", "totals"),
  message: repr(li.unread-options),
)
// optional part set to none, frame part hosted by no area
#assert(
  R(theme.custom.bank-details(show-qr: false), theme.custom.part(
    "bank-details",
    none,
  )).unread-options
    == ("bank-details",),
)
#assert(
  R(theme.custom.page-number(from: 1), theme.custom.area(
    "page-number",
    none,
  )).unread-options
    == ("page-number",),
)

API-TOKENS ASSERTIONS PASSED
