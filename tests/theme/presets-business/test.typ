/// [ppi: 12]

// The business presets, corporate and boxed (prototype tests/preset-checks.typ,
// gallery corporate/boxed, scripts/checks-presets-business.sh):
// - WCAG AA with the preset's own checks.pairs under strict on every layout and
//   on its own (auto), for three brand seeds (resolve-time checks); a dark tint
//   fails them;
// - a 3-page invoice (corporate: 55 items, boxed: 52): continuation header,
//   repeated table header, page numbers;
// - the galleries on their own and on another layout, with ZUGFeRD.
// The widow rule on din-5008-a/a4-digital: tests/theme/widow-layouts; the draft
// renders: tests/validation/draft-corporate, draft-boxed.
#import "/tests/theme/body.typ": body, layouts
#import "/tests/theme/preset-checks.typ": checked-args, checked-theme
#import "/tests/theme/gallery/corporate.typ": gallery as corporate-gallery
#import "/tests/theme/gallery/boxed.typ": gallery as boxed-gallery
#import "/tests/theme/harness.typ": case, case-marker, close-cases, span-of
#import "/src/lib.typ": theme

#let business-layouts = layouts.slice(0, 12) // up to the sidebar layouts
#let env = (kind: "invoice", lang: "de", region: "de", e-invoice: none)
#for look in ("corporate", "boxed") {
  for lay in (auto, ..business-layouts) {
    for seed in (none, "#9fd8f5", "#c2185b") {
      // strict: any pair below 4.5:1 panics and names the pair
      let _ = theme.resolve(
        checked-theme(look, layout: lay, seed: seed),
        env: env,
        validation: "strict",
      )
    }
  }
  // negative: a dark tint must fail (a pair or a core pair names it)
  let dark = catch(() => theme.resolve(
    checked-theme(look, tint: "#333333"),
    env: env,
    validation: "strict",
  ))
  assert(
    dark != none and dark.contains("has contrast"),
    message: look + ": a dark tint must fail the checks, got " + repr(dark),
  )
}

// 3-page invoices
#for (look, n) in (("corporate", 55), ("boxed", 52)) {
  case(look + "/3-pages", ..checked-args(look), body(n: n))
}
// galleries: default layout, another layout, e-invoice
#corporate-gallery(marker: case-marker("corporate/gallery"))
#corporate-gallery(
  layout: "din-5008-a",
  marker: case-marker("corporate/gallery/din"),
)
#corporate-gallery(
  zugferd: true,
  validation: "strict",
  marker: case-marker("corporate/gallery/zugferd"),
)
#boxed-gallery(marker: case-marker("boxed/gallery"))
#boxed-gallery(
  layout: "a4-digital",
  marker: case-marker("boxed/gallery/digital"),
)
#boxed-gallery(
  zugferd: true,
  validation: "strict",
  marker: case-marker("boxed/gallery/zugferd"),
)
#close-cases()
#context {
  for look in ("corporate", "boxed") {
    let p = span-of(look + "/3-pages").pages
    assert(p == 3, message: look + ": " + str(p) + " pages, want 3")
    let s = span-of(look + "/gallery/zugferd")
    let att = query(pdf.attach).filter(a => {
      let q = a.location().page()
      q >= s.first and q < s.first + s.pages
    })
    assert(att.len() == 1, message: look + ": the XML is not attached")
  }
}
