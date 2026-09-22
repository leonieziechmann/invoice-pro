// Labelled sheets of the concept figures (phase 4b). The pages are rendered first by
// out/figures-build.sh into out/f4/; --input fig=<name> picks the sheet.
#let fig = sys.inputs.at("fig", default: "presets")
#let R = "/out/f4/"
#let ink = rgb("#1d2433")
#let muted = rgb("#5b6475")
#let bg = rgb("#eceef2")
#set page(width: auto, height: auto, margin: 7mm, fill: bg)
#set text(font: ("Liberation Sans", "DejaVu Sans Mono"), size: 9pt, fill: ink)

// one page render: a white sheet with a hairline
#let pg(path, w) = block(
  stroke: 0.5pt + rgb("#aeb4bf"),
  fill: white,
  image(R + path, width: w),
)
#let name(t) = text(font: "DejaVu Sans Mono", size: 9pt, weight: "bold", t)
#let note(t) = text(size: 7.5pt, fill: muted, t)
#let cap(n, s: none) = stack(spacing: 1.6mm, name(n), if s != none {
  note(s)
})
#let heading-block(title, sub, w: auto) = block(width: w, below: 5mm, stack(
  spacing: 2mm,
  text(size: 13pt, weight: "bold", title),
  text(size: 8.5pt, fill: muted, sub),
))
#let tile(lbl, body) = stack(spacing: 2.2mm, lbl, body)
// letter pages are wider than A4; scale renders by physical width
#let phys(l) = if l.starts-with("us-letter") { 215.9 / 210 } else { 1 }

#if fig == "presets" {
  let rows = (
    ("classic", "din-5008-a"),
    ("plain", "plain"),
    ("corporate", "a4-sidebar"),
    ("elegant", "din-5008-b"),
    ("prestige", "a4-band"),
    ("bold", "a4-digital"),
    ("technical", "a4-digital"),
    ("soft", "a4-digital"),
    ("compact", "a4-dense"),
    ("boxed", "din-5008-a"),
  )
  heading-block(
    [The ten presets on identical data],
    [Same body, brand colour and logo (tests/matrix.typ, n = 4); page 1; each preset on the layout it picks for a German sender (layout: auto).],
    w: 330mm,
  )
  grid(
    columns: 5,
    column-gutter: 5mm,
    row-gutter: 6mm,
    ..rows.map(((p, l)) => tile(
      cap(p, s: "layout: auto → " + l),
      pg("m/" + p + "-auto-1.png", 62mm),
    )),
  )
} else if fig == "presets-industry" {
  let rows = (
    ("classic", "Structural engineering office, Munich · din-5008-a"),
    ("plain", "Freelance translator, § 19 UStG · plain"),
    ("corporate", "Drive-technology manufacturer · a4-sidebar"),
    ("elegant", "Law and tax partnership · din-5008-b"),
    ("prestige", "Boutique hotel guest folio, Vienna · a4-band"),
    ("bold", "Brand and motion studio, Berlin · a4-digital"),
    ("technical", "Software house, Berlin · a4-digital"),
    ("soft", "Café and bakery with catering · a4-digital"),
    ("compact", "Industrial wholesaler, collective invoice · a4-dense"),
    ("boxed", "Electrician (Handwerk), Kassel · din-5008-a"),
  )
  heading-block(
    [The ten presets in their industries],
    [Page 1 of each preset's gallery invoice (tests/gallery/, tests/figures-gallery.typ); default layout of each preset.],
    w: 330mm,
  )
  grid(
    columns: 5,
    column-gutter: 5mm,
    row-gutter: 6mm,
    ..rows.map(((p, s)) => tile(
      cap(p, s: s),
      pg("g/" + p + "-1.png", 62mm),
    )),
  )
} else if fig == "layouts" {
  let rows = (
    ("din-5008-a", "stable · DE default"),
    ("din-5008-b", "stable · AT default"),
    ("a4-window-right", "experimental · FR/ES/IT default"),
    ("a4-window-left", "experimental · GB default"),
    ("sn-010130-right", "experimental · CH default"),
    ("sn-010130-left", "experimental · CH, window left"),
    ("us-letter-10", "experimental · US default"),
    ("plain", "stable · no furniture"),
    ("a4-digital", "stable · digital-first"),
    ("us-letter-digital", "stable · digital-first, US"),
    ("a4-band", "experimental · prestige"),
    ("us-letter-band", "experimental · prestige, US"),
    ("a4-sidebar", "experimental · corporate"),
    ("us-letter-sidebar", "experimental · corporate, US"),
    ("a4-dense", "experimental · compact"),
    ("us-letter-dense", "experimental · compact, US"),
  )
  heading-block(
    [Every built-in layout with the classic look],
    [theme.classic.with(brand, layout: theme.layout.\<name\>) on identical data (tests/matrix.typ); page 1; Letter pages drawn at true scale relative to A4.],
    w: 250mm,
  )
  grid(
    columns: 4,
    column-gutter: 5mm,
    row-gutter: 6mm,
    align: top,
    ..rows.map(((l, s)) => tile(
      cap(l, s: s),
      pg("l/" + l + "-1.png", 58mm * phys(l)),
    )),
  )
} else if fig == "proof" {
  let rows = (
    ("din-5008-a", "DIN 5008 form A · DL, C6/5, C5, C4"),
    ("sn-010130-right", "SN 010130 · window right"),
    ("a4-window-right", "A4 · window right (FR/ES/IT)"),
    ("us-letter-10", "US Letter · #10 envelope"),
  )
  heading-block(
    [Proof overlays of four window layouts],
    [theme.custom.proof(true): envelope windows, fold and punch marks and the recipient zone drawn over the page; the recipient zone is green when the address shows at least 5 lines in every declared envelope, amber when fewer (the US \#10 window shows 4).],
    w: 337mm,
  )
  grid(
    columns: 4,
    column-gutter: 5mm,
    align: bottom,
    ..rows.map(((l, s)) => tile(
      cap(l, s: s),
      pg("p/" + l + "-1.png", 80mm * phys(l)),
    )),
  )
} else if fig == "validation" {
  heading-block(
    [validation: "draft" (the default)],
    [Four open problems (invoice number, supplier tax ID, recipient address, buyer electronic address for EN 16931): the draft badge and the ‹…› markers on page 1, the Prüfbericht appended as the last page. "strict" stops the compilation instead; none renders silently.],
    w: 216mm,
  )
  grid(
    columns: 2,
    column-gutter: 6mm,
    tile(
      cap("page 1", s: "badge, watermark, ‹…› markers where data is missing"),
      pg(
        "v/draft-1.png",
        105mm,
      ),
    ),
    tile(cap("page 2", s: "Prüfbericht: problem, legal basis, fix"), pg(
      "v/draft-2.png",
      105mm,
    )),
  )
} else if fig == "stationery" {
  let modes = (
    (
      "print",
      "stationery(\"pre-printed\")",
      "letterhead left blank for pre-printed paper",
    ),
    (
      "pdf",
      "stationery((first: .., rest: ..))",
      "letterhead art placed under each page",
    ),
    (
      "einvoice",
      "stationery: none (default)",
      "generated letterhead + ZUGFeRD",
    ),
  )
  heading-block(
    [The three stationery modes],
    [One document (tests/doc/p2.typ with figure art: tests/figures-stationery.typ; 26 items, classic on DIN 5008 form B) printed on pre-printed paper, as a PDF with letterhead art, and as a generated e-invoice; pages 1 and 2 each.],
    w: 333mm,
  )
  grid(
    columns: 3,
    column-gutter: 7mm,
    ..modes.map(((m, code, s)) => tile(
      stack(spacing: 1.6mm, name("output=" + m), note(raw(code)), note(s)),
      stack(
        dir: ltr,
        spacing: 2.5mm,
        pg("s/p2-" + m + "-1.png", 52mm),
        pg("s/p2-" + m + "-2.png", 52mm),
      ),
    )),
  )
} else if fig == "any-format" {
  heading-block(
    [Any format is data],
    [Left: a third-party package ships an A5 landscape sidebar layout (zero imports of invoice-pro internals). Right: an 80 mm thermal-roll receipt (paper height: auto) with theme.plain.],
    w: 208mm,
  )
  grid(
    columns: 2,
    column-gutter: 8mm,
    align: top,
    tile(
      cap(
        "@local/acme-theme · sidebar-a5",
        s: "A5 landscape, 210 × 148 mm; pages 1 and 2",
      ),
      stack(spacing: 4mm, pg("a/p9-1.png", 128mm), pg("a/p9-2.png", 128mm)),
    ),
    tile(
      cap(
        "roll-80",
        s: "80 mm × auto (height grows with the content); drawn at 1.6× the A5 scale",
      ),
      pg("a/rc-1.png", 72mm),
    ),
  )
} else if fig == "matrix" {
  let looks = ("classic", "corporate", "prestige", "technical", "boxed")
  let lays = ("din-5008-a", "sn-010130-right", "us-letter-10", "a4-digital")
  heading-block(
    [Any look on any layout],
    [Five presets × four layouts on identical data: looks patch tokens and style, never geometry (CI: tests/looks.typ renders the full matrix).],
    w: 205mm,
  )
  grid(
    columns: (auto,) + (auto,) * lays.len(),
    column-gutter: 4mm,
    row-gutter: 4mm,
    align: center + top,
    [], ..lays.map(l => name(l)),
    ..looks
      .map(k => (
        align(horizon, rotate(-90deg, reflow: true, name(k))),
        ..lays.map(l => pg("m/" + k + "-" + l + "-1.png", 46mm * phys(l))),
      ))
      .flatten()
  )
}
