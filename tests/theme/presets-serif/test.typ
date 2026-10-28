/// [ppi: 12]

// The serif family, elegant and prestige (prototype tests/presets-serif.typ,
// gallery elegant/prestige, scripts/checks-presets-serif.sh): layout by region,
// contrast under strict incl. the family's checks.pairs and strong brand seeds,
// one parts family, the band layouts; page budgets (4 items on one page on the
// default layout and on DIN 5008 A/B; the galleries on 2 and 1 pages; 3-page
// invoices with continuation header and page numbers), the galleries under
// strict with image logos, and ZUGFeRD attaching the XML (the draft renders:
// tests/validation/draft-elegant, draft-prestige).
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

#import "/tests/theme/body.typ": body, layout-of, logo-img, party, preset-of
#import "/tests/theme/gallery/elegant.typ": gallery as elegant-gallery
#import "/tests/theme/gallery/prestige.typ": gallery as prestige-gallery
#import "/tests/theme/harness.typ": case, case-marker, close-cases, span-of
#import "/tests/test-locale.typ": test-locale

#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
#let budgets = (
  ("elegant/din-5008-b", 1), // its default layout
  ("elegant/din-5008-a", 1),
  ("prestige/a4-band", 1), // its default layout
  ("prestige/din-5008-b", 1),
)
#for (key, _) in budgets {
  let (look, lay) = key.split("/")
  case(
    key,
    theme: preset-of(look).with(brand, layout: layout-of(lay)),
    locale: test-locale,
    ..party,
    body(n: 4),
  )
}
// galleries under strict (identity check, 4.5:1 contrast incl. checks.pairs)
#let galleries = (
  ("elegant/gallery", 2, elegant-gallery.with(validation: "strict")),
  ("prestige/gallery", 1, prestige-gallery.with(validation: "strict")),
  // 3-page invoices: continuation header, page numbers, repeated table header
  (
    "elegant/3-pages",
    3,
    elegant-gallery.with(validation: "strict", extra: 30),
  ),
  // (extra 36: with the core widow rule the folio needs more lines for page 3)
  (
    "prestige/3-pages",
    3,
    prestige-gallery.with(validation: "strict", extra: 36),
  ),
  // image logos with alt text (the prototype exported them to PDF/UA-1)
  (
    "elegant/logo",
    none,
    elegant-gallery.with(validation: "strict", logo: true),
  ),
  (
    "prestige/plate-din",
    none,
    prestige-gallery.with(
      validation: "strict",
      logo: "plate",
      layout: "din-5008-b",
    ),
  ),
  // ZUGFeRD (the prototype exported them to PDF/A-3b)
  (
    "elegant/zugferd",
    none,
    elegant-gallery.with(validation: "strict", zugferd: true),
  ),
  (
    "prestige/zugferd",
    none,
    prestige-gallery.with(validation: "strict", zugferd: true),
  ),
)
#for (key, _, gallery) in galleries { gallery(marker: case-marker(key)) }
#close-cases()
#context {
  for (key, want) in budgets + galleries.map(((k, w, _)) => (k, w)) {
    if want == none { continue }
    let got = span-of(key).pages
    assert(
      got == want,
      message: key + ": " + str(got) + " pages, want " + str(want),
    )
  }
  for key in ("elegant/zugferd", "prestige/zugferd") {
    let s = span-of(key)
    let att = query(pdf.attach).filter(a => {
      let p = a.location().page()
      p >= s.first and p < s.first + s.pages
    })
    assert(att.len() == 1, message: key + ": the XML is not attached")
  }
}
