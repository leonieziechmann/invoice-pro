/// [ppi: 12]

// Footer fit and clearance (prototype tests/api-frame/footer-fit.typ,
// scripts/checks-api-frame.sh): on every layout, classic and corporate, under
// strict, the last line of every legal footer part (its descenders included)
// ends at least `footer-clearance` (5 mm) above the sheet edge, on page 1 (with
// "Page 1 of 2") and page 2. Negative control: an explicit bottom margin of
// 24 mm under validation none puts a footer below the clearance, and the probe
// sees it (strict and draft: tests/validation/draft-findings).
#import "/tests/theme/body.typ": *
#import "/tests/theme/footer-fit.typ": footer-args
#import "/tests/theme/harness.typ": case, close-cases, in-case, span-of

#let lays = (
  "din-5008-a",
  "din-5008-b",
  "us-letter-10",
  "a4-digital",
  "us-letter-digital",
  "sn-010130-right",
  "sn-010130-left",
  "a4-window-right",
  "a4-window-left",
  "plain",
)
#let cases = ("classic", "corporate").map(l => lays.map(y => (l, y))).join()
#for (look, lay) in cases {
  case(
    look + "/" + lay,
    ..footer-args(look, lay, validation: "strict"),
    body(n: 30),
  )
}
#case(
  "margin-24",
  ..footer-args("classic", "din-5008-a", margin: 24, validation: none),
  body(n: 30),
)
#close-cases()

// where each footer part ends above the sheet edge; a block ends at its last
// baseline, so the descenders of the look's fine footer text are added
#let above-edge(key, look, lay) = {
  let s = span-of(key)
  let t = theme.resolve(preset-of(look)).tokens
  let desc = measure(text(
    font: t.fonts.body,
    size: t.sizes.fine,
    top-edge: "baseline",
    bottom-edge: "descender",
  )[gjpqy]).height
  let ph = if lay in ("us-letter-10", "us-letter-digital") { 279.4mm } else {
    297mm
  }
  query(<foot-end>)
    .filter(m => {
      let p = m.location().page()
      p >= s.first and p < s.first + s.pages
    })
    .map(m => (
      part: m.value,
      page: m.location().page() - s.first + 1,
      gap: ph - m.location().position().y - desc,
    ))
}
#context {
  for (look, lay) in cases {
    let key = look + "/" + lay
    let ends = above-edge(key, look, lay)
    assert(
      ends.len() >= 2,
      message: key
        + ": the footer parts did not render ("
        + str(ends.len())
        + ")",
    )
    for e in ends {
      assert(
        e.gap >= 5mm - 0.05mm,
        message: key
          + ": footer part "
          + e.part
          + " on page "
          + str(e.page)
          + " ends "
          + str(calc.round(e.gap / 1mm, digits: 2))
          + "mm above the sheet edge (clearance 5mm)",
      )
    }
    assert(
      span-of(key).pages >= 2,
      message: key + ": the test needs a second page",
    )
    let pages = ends.map(e => e.page).dedup()
    assert(1 in pages and 2 in pages, message: key + ": footer on both pages")
  }
  // the negative control trips the probe
  let low = above-edge("margin-24", "classic", "din-5008-a").filter(e => (
    e.gap < 5mm
  ))
  assert(
    low.len() > 0,
    message: "footer probe: a 24mm bottom margin must put a footer below the clearance",
  )
}
