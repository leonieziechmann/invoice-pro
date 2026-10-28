// Envelope fit of every window layout (prototype tests/envelopes.typ, concept
// §8.2): for each declared envelope, the recipient box shows >= 5 lines (US
// Letter #10: >= 4) of >= 60 mm, with 2 mm clearance inside the window, in EVERY
// position the folded sheet can take inside the envelope. Checked with the
// documented line metrics (first line 3.17 mm, pitch 4.37 mm: Liberation Sans
// 10 pt, leading 0.5em), which also pin the documented limits (C4 form B, US #10
// in equal thirds), and with the metrics of classic's recipient text as it
// renders here (its font chain ends in the embedded Libertinus Serif).
#import "/src/lib.typ": *
#import "/src/theming/proof.typ": window-fit
#import "/src/theming/validate.typ": area-rect, paper-dims

#let R(l) = theme.resolve(theme.classic.with(layout: l)).layout
#let expect = (
  "din-5008-a": 5,
  "din-5008-b": 5,
  "sn-010130-right": 5,
  "sn-010130-left": 5,
  "a4-window-right": 5,
  "a4-window-left": 5,
  "us-letter-10": 4,
)
#let check(m, label, limits: false) = {
  for (name, need) in expect {
    let L = R(dictionary(theme.layout).at(name))
    let (pw, ph) = paper-dims(L)
    let fits = window-fit(L, pw, ph, area-rect, first: m.first, pitch: m.pitch)
    assert(
      fits.len() == L.envelopes.len() and fits.len() > 0,
      message: label + " " + name + ": no envelopes / no recipient box",
    )
    for f in fits {
      assert(
        f.lines >= need,
        message: label
          + " "
          + name
          + " in "
          + f.name
          + ": only "
          + str(f.lines)
          + " lines always show",
      )
      assert(
        f.width >= 60mm,
        message: label
          + " "
          + name
          + " in "
          + f.name
          + ": lines only "
          + repr(f.width),
      )
    }
  }
  // switching the printed marks off keeps the fold scheme (envelopes pin their folds)
  let dig = R(theme.layout.din-5008-b) + (marks: none)
  assert(
    window-fit(
      dig,
      210mm,
      297mm,
      area-rect,
      first: m.first,
      pitch: m.pitch,
    ).all(f => f.lines >= 5),
    message: label + ": marks(none) keeps the folds",
  )
  if not limits { return }
  // documented limits: a flat A4 in a C4 form-B envelope, equal thirds in a #10
  let b = R(theme.layout.din-5008-b)
  let c4 = window-fit(
    b + (envelopes: (theme.layout.envelope.din-c4-b,)),
    210mm,
    297mm,
    area-rect,
    first: m.first,
    pitch: m.pitch,
  )
  assert(c4.first().lines == 4, message: label + ": C4 form B")
  let us = R(theme.layout.us-letter-10)
  let thirds = window-fit(
    us + (envelopes: us.envelopes.map(e => e + (fold: (11in / 3, 22in / 3)))),
    215.9mm,
    279.4mm,
    area-rect,
    first: m.first,
    pitch: m.pitch,
  )
  assert(thirds.first().lines < 4, message: label + ": #10 in equal thirds")
}

#check((first: 3.17mm, pitch: 4.37mm), "documented metrics:", limits: true)
#context {
  let t = theme.resolve(theme.classic).tokens
  let st(..a, b) = text(font: t.fonts.body, size: t.sizes.body, ..a, b)
  let one = measure(st[Xg]).height
  let two = measure(par(leading: 0.5em, st[Xg \ Xg])).height
  check(
    (
      first: measure(st(
        top-edge: "cap-height",
        bottom-edge: "descender",
      )[Xg]).height,
      pitch: two - one,
    ),
    "rendered metrics:",
  )
}

// mapping by the SENDER's region
#assert(theme.layout.for-region("ch").name == "sn-010130-right")
#assert(theme.layout.for-region("FR").name == "a4-window-right")
#assert(theme.layout.for-region("xx").name == "din-5008-a")
