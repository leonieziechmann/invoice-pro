// Serif family presets (elegant, prestige): layout by region, contrast under
// strict checks (incl. the family's checks.pairs), the shared parts, a strong-
// brand stress (light and dark seeds keep every checked pair legible), and the
// band layouts.
#import "/src/lib.typ": *
#import "/src/theming/looks/serif.typ" as serif

#let env(r) = (kind: "invoice", lang: "de", region: r, e-invoice: none)
#let name(th, r) = theme.resolve(th, env: env(r)).layout.name

// layout: auto. elegant: the region's window layout, DIN form B instead of form A
#assert.eq(name(theme.elegant, "de"), "din-5008-b")
#assert.eq(name(theme.elegant, none), "din-5008-b")
#assert.eq(name(theme.elegant, "nl"), "din-5008-b")
#assert.eq(name(theme.elegant, "at"), "din-5008-b")
#assert.eq(name(theme.elegant, "ch"), "sn-010130-right")
#assert.eq(name(theme.elegant, "fr"), "a4-window-right")
#assert.eq(name(theme.elegant, "gb"), "a4-window-left")
#assert.eq(name(theme.elegant, "us"), "us-letter-10")
// prestige: the band layout on the region's paper
#assert.eq(name(theme.prestige, "de"), "a4-band")
#assert.eq(name(theme.prestige, "at"), "a4-band")
#assert.eq(name(theme.prestige, "us"), "us-letter-band")
#assert.eq(
  theme.resolve(theme.prestige, env: env("us")).layout.paper,
  "us-letter",
)
// an explicit layout wins
#assert.eq(
  name(theme.prestige.with(layout: theme.layout.din-5008-b), "de"),
  "din-5008-b",
)
#assert.eq(theme.layout.band-for-region("US").name, "us-letter-band")

// strict contrast (4.5:1) on the defaults and under strong brand seeds: every
// checked pair, incl. checks.pairs::serif-key-labels (accent used as text)
#for th in (theme.elegant, theme.prestige) {
  for seed in (
    none,
    rgb("#f5d000"),
    rgb("#0f766e"),
    rgb("#111111"),
    rgb("#e8e0ff"),
  ) {
    let p = if seed == none { () } else {
      theme.custom.colors(primary: seed, accent: seed)
    }
    let r = theme.resolve(
      th.with(p, theme.custom.checks(min-contrast: 4.5)),
      validation: "strict",
    )
    assert("serif-key-labels" in r.checks.pairs)
  }
}
// prestige: onyx surface in the letterhead, champagne text on it, champagne rules
#let p = theme.resolve(theme.prestige)
#assert.eq(p.layout.areas.letterhead.fill, rgb("#1c1a17"))
#assert.eq(p.layout.areas.letterhead.text.fill, p.tokens.colors.on-primary)
#assert.eq(p.tokens.colors.border, rgb("#c8a96b"))
#assert(p.tokens.colors.accent-text != p.tokens.colors.accent) // champagne fails 4.5:1 as text
// the same parts in both presets (one family)
#let e = theme.resolve(theme.elegant)
#for part in (
  "sender",
  "return-address",
  "recipient",
  "title",
  "continuation",
  "totals",
  "bank-details",
  "reference-list",
) {
  assert(
    e.parts.at(part) == p.parts.at(part),
    message: "part " + part + " differs between elegant and prestige",
  )
  assert(
    e.parts.at(part) == dictionary(serif).at(part),
    message: "part " + part + " is not the serif family's",
  )
}
// elegant: no filled areas
#for (n, a) in e.layout.areas {
  if a != none { assert(a.fill == none, message: "elegant fills area " + n) }
}
// unread-options only names the groups whose built-in reader the family replaced;
// the serif title / totals / bank-details renderers honour them (all their keys)
#assert.eq(e.unread-options.sorted(), ("bank-details", "title", "totals"))
#assert.eq(p.unread-options.sorted(), ("bank-details", "title", "totals"))
// the band: full-bleed fixed first-page area, pushes the body down, stationery
#let b = theme.layout.a4-band.areas.letterhead
#assert(b.left == 0mm and b.top == 0mm and b.width == 100% and b.stationery)
SERIF PRESET ASSERTIONS PASSED
