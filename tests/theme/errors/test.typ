/// [ppi: 12]

// The error suite (prototype tests/errors/err.typ and expected.txt, compared
// byte for byte by scripts/run-all.sh under --input invoice-pro-validation=strict):
// 41 cases, the message of each exactly as a caught panic (tytanic `catch`), with
// validation: "strict" passed as the parameter (the --input override is covered
// by tests/validation/api). Case classes:
// - misuse (24 cases) panics under every level, with the same message under none;
// - follow-level (17 cases) panics only under strict: under draft and none the
//   evaluation passes, and the rendered invoices (15 cases, below) publish the
//   strict message as draft issues (panic-text of the <ip-issue> records), and
//   none publishes nothing. Case 17's fixture is not a real PDF, so it cannot
//   render (as in the prototype).
// Two follow-level checks run only after layout, where `catch` cannot see them:
// case 28 (footer fit) is checked here through its draft issue; case 25 (the
// identity check) in tests/validation/identity-missing.
#import "/tests/theme/body.typ": *
#import "/tests/theme/harness.typ": case-marker, close-cases, issues-of
#import "/src/validation/issue.typ": panic-text
#import theme.custom: *

#let tall = [#for i in range(14) [Line #i #linebreak()]]
#let themes = (
  "1": () => theme.classic.with((tokens: (colors: (primry: red)))),
  "2": () => theme.classic.with(form: "B"),
  "3": () => theme.classic.with(area("adress", top: 50mm)),
  "4": () => theme.classic.with(area("address", none)),
  "5": () => theme.corporate.with(area("title", parts: ("logo",))),
  "6": () => theme.classic.with(part("notes", none)),
  "7": () => theme.classic.with(part("notes", (ctx, view) => none)),
  "8": () => theme.classic.with(logo(
    image: image(
      "/tests/theme/assets/lh1.svg",
    ),
  )),
  "9": () => theme.classic.with(area(
    "stamp",
    place: "fixed",
    left: 60mm,
    top: 40mm,
    width: 40mm,
    height: 20mm,
    parts: ([COPY],),
  )),
  "10": () => theme.classic.with(colors(
    tint: t => t.colors.text-muted,
    text-muted: t => t.colors.tint.lighten(5%),
  )),
  "11": () => theme.classic.with(checks(min-contrast: 4.5), colors(
    text-muted: rgb("#f472b6"),
  )),
  "12": () => theme.classic.with(part("signatur", (ctx, view) => [x])),
  "13": () => theme.classic.with((colours: (primary: red))),
  "14": () => theme.classic.with(colors(primary: "#ff0000")),
  "15": () => theme.classic.with(page(paper: "a44")),
  "16": () => theme.classic,
  "17": () => theme.classic.with(
    stationery((first: image("/tests/theme/assets/fake.pdf"))),
    marks(none),
  ),
  "18": () => theme.classic.with(area("title", pages: "rest")),
  "19": () => theme.classic.with(theme.custom.from-data((
    tokens: (colors: (primary: "#fff")),
    options: (logo: (image: "x.svg")),
  ))),
  "22": () => theme.classic.with(colors(primary: red), 42),
  "24": () => theme.classic.with(part("totals", (ctx, view) => none)),
  "25": () => theme.classic.with(part("title", (ctx, view) => [Dear customer])),
  "26": () => theme.plain.with(area("letterhead", none)),
  "27": () => theme.classic.with(area("address", pages: "all")),
  "28": () => theme.classic.with(page(margin: (bottom: 32mm)), area(
    "footer",
    parts: (tall,),
  )),
  "29": () => theme.classic.with(sizes(fine: 5pt)),
  "30": () => theme.classic.with((
    options: (
      title: (color: ("__invoice-pro-wrap__": (ctx, view, inner) => none)),
    ),
  )),
  "32": () => theme.classic.with(
    layout: theme.layout.reserve-qr-bill(theme.layout.sn-010130-right),
    page(paper: "us-letter"),
  ),
  "33": () => theme.classic.with(colors(primary: cmyk(80%, 20%, 0%, 10%))),
  "34": () => theme.classic.with(items-table(zebra: ("red", 12))),
  "35": () => theme.classic.with(page-number(format: "Seite")),
  "36": () => theme.classic.with(area("address", left: 22mm, right: 20mm)),
  "37": () => theme.classic.with(envelopes((
    name: "c6",
    size: (162mm, 114mm),
    window: (left: 15mm, bottom: 15mm, width: 90mm, height: 45mm),
  ))),
  "38": () => theme.classic.with(proof(("dl",))),
  "39": () => theme.classic.with(envelopes((
    name: "x",
    size: (220mm, 110mm),
    window: (left: 20mm, right: 20mm, width: 90mm, height: 45mm),
  ))),
  "40": () => theme.classic.with(layout: env => "din-5008-a"),
  "41": () => theme.classic.with(stationery("generated")),
)

/// Case c of err.typ as an invoice (or the resolve call of case 31); `marker`
/// starts the invoice body.
#let run(c, level, marker: none) = {
  if c == "31" {
    return theme.resolve(theme.classic, env: (
      kind: "banana-note",
      lang: "de",
      region: "de",
      e-invoice: none,
    ))
  }
  let t = themes.at(c, default: () => theme.classic)()
  invoice(
    theme: if c == "16" { (colors: (primary: red)) } else { t },
    locale: test-locale,
    zugferd: if c in ("17", "33") { "basic" },
    tax-exempt-small-biz: c == "7",
    validation: level,
    ..party,
    [
      #marker
      #if c == "20" { themed(area("address", top: 1mm))[x] }
      #if c == "21" { themed(tokens: 1)[x] }
      #if c == "23" {
        themed(wrap("title", (ctx, view, inner) => [SCOPED]))[x]
      }
      #body()
    ],
  )
}

#let expected = (
  "1": "theme::tokens::colors has unknown key `primry`. Did you mean `primary`? Allowed keys: primary, on-primary, primary-text, accent, accent-text, text, text-muted, border, tint, background",
  "2": "theme `classic`: unexpected named argument(s) `form`. A theme takes patches (e.g. `.with(theme.custom.colors(primary: teal))`) and `layout:` (e.g. `layout: theme.layout.din-5008-b`). `form` is a 0.4 `themes.DIN-5008` parameter; see the migration table in the theme docs.",
  "3": "theme::layout::areas has no area `adress` in layout `din-5008-a`. Did you mean `address`? Existing areas: marks, letterhead, address, info, references, title, continuation, page-number, footer. To ADD an area, give it a `place`.",
  "4": "theme::layout (din-5008-a) must host `recipient` in exactly one first-page (tagged) or flow area (found 0). It carries legally required output: recipient name and address (§ 14 UStG; EN 16931 BG-7). Restyle it by replacing its renderer, but keep it placed.",
  "5": "theme::layout (a4-sidebar) must host `title` in at least one first-page (tagged) or flow area (found 0). It carries legally required output: document identity: invoice number and date (§ 14 UStG; EN 16931 BT-1, BT-2). Restyle it by replacing its renderer, but keep it placed.",
  "6": "theme::parts::notes carries legally required output and cannot be `none`; wrap it or replace its renderer instead",
  "7": "theme::parts::notes returned no content, but it must render legally required output",
  "8": "theme::options::logo::image needs alt text, e.g. image(\"logo.svg\", alt: \"ACME GmbH\") (checked always: a document cannot see --pdf-standard, and PDF/UA-1 requires it)",
  "9": "theme::layout::areas::stamp overlaps the address window area `address`; move it or shrink it (envelope windows must stay clear)",
  "10": "theme::tokens: derivations form a cycle (colors::text-muted, colors::tint); every chain of `t => ..` must end in a literal value",
  "11": "invoice-pro found 2 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):\n  1. theme: colors::text-muted on colors::background has contrast 2.65:1, below checks.min-contrast 4.5:1\n  2. theme: colors::text-muted on colors::tint has contrast 2.15:1, below checks.min-contrast 4.5:1",
  "12": "theme::parts::signatur is not a built-in part. Did you mean `signature`? Custom parts need a package prefix, e.g. `acme/rail` (un-prefixed names are reserved for built-ins).",
  "13": "theme: unknown patch group `colours`. Allowed groups: tokens, options, parts, layout, checks",
  "14": "variable `theme::tokens::colors::primary`(\"#ff0000\") must be of color (or a derivation `t => ..`)",
  "15": "theme::layout::paper `a44` has no known size; use (width:, height:). Did you mean `a4`? Known: ISO a0-a10, b0-b10, c0-c10, us-letter, us-legal, us-executive, us-tabloid",
  "16": "variable `invoice::theme` must be of function (a lazy theme such as `theme.classic`), found dictionary. For a brand file write `theme.classic.with(theme.custom.from-data(toml(\"brand.toml\")))`.",
  "17": "theme::layout::stationery::first embeds a PDF image; PDF/A and PDF/UA exports cannot embed PDF images (Typst limitation). Convert the letterhead to SVG",
  "18": "theme::layout::areas::title::pages applies only to fixed, header, footer, background and foreground areas; flow areas appear once",
  "19": "theme::custom::from-data: `options::logo::image` is the path \"x.svg\"; packages cannot open files by path. Pass `assets: p => image(p, alt: ..)` from your document.",
  "20": "themed: layout patches are document-level (the page master cannot change mid-document); pass them to `invoice(theme: ..)`",
  "21": "themed: unexpected named argument(s) `tokens`; pass patches, e.g. themed(theme.custom.colors(primary: red))[..]",
  "22": "theme `classic`: patch #2 must be a theme.custom result or a patch dictionary, found integer (42)",
  "23": "themed: `parts::title` belongs to the page frame, which is drawn once per document; pass it to `invoice(theme: ..)`",
  "24": "theme::parts::totals returned no content, but it must render legally required output",
  "25": "theme: the invoice number (2026-0142) does not appear in the first-page content; the area hosting `title` must render view.document.number (§ 14 UStG; EN 16931 BT-1)",
  "26": "theme::layout (plain) must host `sender` or `company` or `return-address` in at least one area drawn on page 1 (found 0). It carries legally required output: supplier name and address (§ 14 UStG; EN 16931 BG-4). Restyle it by replacing its renderer, but keep it placed.",
  "27": "theme::layout::areas::address is a fixed area on following pages (pages: \"all\") and would overprint the body there; use pages: \"first\" or move it into the margins",
  // the footer is measured: 42.2mm with Liberation Sans (the prototype's
  // expected.txt), 41.2mm with the embedded Libertinus Serif that tytanic uses
  "28": "theme::layout::areas::footer is 41.2mm tall, but the bottom margin leaves 17.4mm between footer-descent and the 5mm footer-clearance; use the computed margin (theme.custom.page(margin: (bottom: reset()))), raise margin.bottom or shorten the footer",
  "29": "theme::tokens::sizes::fine (5pt) must be an absolute length of at least 6pt (DIN 5008 minimum for the return address and legal footer)",
  "30": "theme::options::title::color: a wrap marker is only valid for a part (theme.custom.wrap(name, ..)), not here",
  "31": "theme::env::kind `banana-note` is not a document kind. Known kinds: invoice, credit-note, corrected-invoice, prepayment-invoice, proforma-invoice, quote, order-confirmation, delivery-note, payment-reminder, receipt, letter",
  "32": "theme::layout (sn-010130-right) hosts `qr-bill`, which needs A4 portrait paper (SIX QR-bill: 210 x 105 mm slip)",
  "33": "invoice-pro found 2 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):\n  1. theme::tokens::colors::primary is a CMYK colour; Typst cannot embed a CMYK output profile, so PDF/A-3 (ZUGFeRD) rejects it. Use rgb() or oklch().\n  2. theme::tokens::colors::accent is a CMYK colour; Typst cannot embed a CMYK output profile, so PDF/A-3 (ZUGFeRD) rejects it. Use rgb() or oklch().",
  "34": "variable `theme::options::items-table::zebra`((\"red\", 12)) must be of array of none | color | function",
  "35": "variable `theme::options::page-number::format`(\"Seite\") must be of auto | function",
  "36": "theme::layout::areas::address needs exactly one of `left` or `right` (place: \"fixed\")",
  "37": "theme::layout::envelopes::c6 does not take the folded sheet: packet 210 x 105 mm, envelope 162 x 114 mm; check the paper, `marks.fold` or the envelope's `fold`",
  "38": "theme::layout::proof names envelope `dl`, which the layout does not list. Listed: din-dl, din-c6-5, din-c5-a, din-c4-a",
  "39": "theme::layout::envelopes::0::window needs exactly one of `left` or `right`",
  "40": "theme `classic`: the layout resolver `env => ..` must return a layout dictionary (such as `theme.layout.din-5008-b`), found \"din-5008-a\"",
  "41": "theme::layout::stationery must be none (the theme draws everything), \"pre-printed\" or (first: content, rest: content), found \"generated\"",
)

#let cases = range(1, 42).map(str)
#let follow-level = (
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "11",
  "17",
  "24",
  "25",
  "26",
  "27",
  "28",
  "29",
  "32",
  "33",
  "37",
)
#let misuse = cases.filter(c => c not in follow-level)
#assert(misuse.len() == 24 and follow-level.len() == 17)
#let panicked(message) = "panicked with: " + repr(message)

// strict: every case stops with its message (25 and 28 only after layout)
#for c in cases.filter(c => c not in ("25", "28")) {
  assert.eq(
    catch(() => run(c, "strict")),
    panicked(expected.at(c)),
    message: "case " + c + " (strict)",
  )
}
// misuse panics under every level, also under none
#for c in misuse {
  assert.eq(
    catch(() => run(c, none)),
    panicked(expected.at(c)),
    message: "case " + c + " (none)",
  )
}
// follow-level: draft and none evaluate without a panic
#for c in follow-level {
  for level in ("draft", none) {
    assert.eq(
      catch(() => run(c, level)),
      none,
      message: "case " + c + " (" + repr(level) + ")",
    )
  }
}

// follow-level cases render under draft and none (25: its own document; 17: the
// fixture is not a real PDF); a draft publishes what strict panics with
#let rendered = follow-level.filter(c => c not in ("17", "25"))
#for c in rendered {
  for level in ("draft", none) {
    let key = c + "/" + (if level == none { "none" } else { level })
    run(c, level, marker: case-marker(key))
  }
}
#close-cases()
// A title that no area hosts (case 5) also fails the identity check, which runs
// after layout: strict stops before it, a draft reports both.
#let after-layout = (
  "5": ("theme/identity-number", "theme/identity-date"),
)
#context for c in rendered {
  let draft = issues-of(c + "/draft")
  assert(draft.len() > 0, message: "case " + c + ": no draft issue")
  let later = after-layout.at(c, default: ())
  assert.eq(
    draft.filter(x => x.id in later).map(x => x.id),
    later,
    message: "case " + c + " (issues after layout)",
  )
  assert.eq(
    panic-text(draft.filter(x => x.id not in later)),
    expected.at(c),
    message: "case " + c + " (draft issues)",
  )
  assert.eq(issues-of(c + "/none"), (), message: "case " + c + " (none)")
}
