// Compile-fail suite: `--input case=N`; expected first error lines in expected.txt.
#import "/tests/body.typ": *
#import theme.custom: *
#let c = sys.inputs.at("case", default: "1")
#let tall = [#for i in range(14) [Line #i #linebreak()]]
#let t = (
  "1": () => theme.classic.with((tokens: (colors: (primry: red)))),
  "2": () => theme.classic.with(form: "B"),
  "3": () => theme.classic.with(area("adress", top: 50mm)),
  "4": () => theme.classic.with(area("address", none)),
  "5": () => theme.corporate.with(area("title", parts: ("logo",))),
  "6": () => theme.classic.with(part("notes", none)),
  "7": () => theme.classic.with(part("notes", (ctx, view) => none)),
  "8": () => theme.classic.with(logo(image: image("/tests/lh1.svg"))),
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
    stationery((first: image("/tests/fake.pdf"))),
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
).at(c, default: () => theme.classic)()
#if c == "31" {
  let _ = theme.resolve(theme.classic, env: (
    kind: "banana-note",
    lang: "de",
    region: "de",
    e-invoice: none,
  ))
}
#let arg = if c == "16" { (theme: (colors: (primary: red))) } else {
  (theme: t)
}
#show: invoice.with(
  ..arg,
  locale: test-locale,
  zugferd: if c in ("17", "33") { "basic" },
  tax-exempt-small-biz: c == "7",
  ..party,
)
#if c == "20" { themed(area("address", top: 1mm))[x] }
#if c == "21" { themed(tokens: 1)[x] }
#if c == "23" { themed(wrap("title", (ctx, view, inner) => [SCOPED]))[x] }
#body()
