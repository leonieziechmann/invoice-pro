/// [ppi: 12]

// Every preset under strict (prototype tests/preset-checks.typ,
// scripts/checks-presets.sh), on its own layout (German sender):
// - WCAG AA: checks(min-contrast: 4.5) with the core pairs and the preset's
//   checks.pairs holds for three brand seeds (the preset's own, a pale and a
//   saturated one);
// - ZUGFeRD with an image logo that carries alt text: the XML is attached (the
//   prototype exported these to PDF/A-3b and PDF/UA-1; the PDF standards are not
//   portable to tytanic, which renders PNG pages).
// A 4-item invoice on one page per preset and region: tests/theme/one-page.
#import "/tests/theme/body.typ": body, presets
#import "/tests/theme/preset-checks.typ": checked-args
#import "/tests/theme/harness.typ": case, close-cases, span-of

#let seeds = (none, "#9fd8f5", "#c2185b")
#for look in presets {
  for seed in seeds {
    case(
      look + "/" + repr(seed),
      ..checked-args(look, seed: seed, validation: "strict"),
      body(n: 4),
    )
  }
  case(
    look + "/zugferd",
    ..checked-args(look, image-logo: true, zugferd: true, validation: "strict"),
    body(n: 4),
  )
}
#close-cases()
#context for look in presets {
  let s = span-of(look + "/zugferd")
  let att = query(pdf.attach).filter(a => {
    let p = a.location().page()
    p >= s.first and p < s.first + s.pages
  })
  assert(
    att.map(a => a.path) == ("/factur-x.xml",),
    message: look + ": the XML is not attached",
  )
}
