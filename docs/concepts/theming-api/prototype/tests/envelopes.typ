// Envelope fit of every window layout (country-layouts study). For each declared
// envelope, the recipient box must show >= 5 lines (US Letter #10: >= 4) of the
// classic recipient text and lines of >= 60 mm, with 2 mm clearance inside the
// window, in EVERY position the folded sheet can take inside the envelope.
#import "/src/lib.typ": *
#import "/src/theming/proof.typ": envelope-band, window-fit
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
#context {
  let st(..a, b) = text(font: "Liberation Sans", size: 10pt, ..a, b)
  let one = measure(st[Xg]).height
  let two = measure(par(leading: 0.5em, st[Xg \ Xg])).height
  let m = (
    first: measure(st(
      top-edge: "cap-height",
      bottom-edge: "descender",
    )[Xg]).height,
    pitch: two - one,
  )
  let out = ()
  for (name, need) in expect {
    let L = R(dictionary(theme.layout).at(name))
    let (pw, ph) = paper-dims(L)
    let fits = window-fit(L, pw, ph, area-rect, first: m.first, pitch: m.pitch)
    assert(
      fits.len() == L.envelopes.len() and fits.len() > 0,
      message: name + ": no envelopes / no recipient box",
    )
    for f in fits {
      assert(
        f.lines >= need,
        message: name
          + " in "
          + f.name
          + ": only "
          + str(f.lines)
          + " lines always show",
      )
      assert(
        f.width >= 60mm,
        message: name + " in " + f.name + ": lines only " + repr(f.width),
      )
      out.push((
        name,
        f.name,
        str(f.lines),
        str(calc.round(f.width / 1mm, digits: 1)),
        str(calc.round(f.band.y / 1mm, digits: 1))
          + "-"
          + str(calc.round((f.band.y + f.band.h) / 1mm, digits: 1)),
      ))
    }
  }
  // documented limits (REPORT.md): a flat A4 in a C4 form-B envelope, equal thirds in a #10
  let b = R(theme.layout.din-5008-b)
  let c4 = window-fit(
    b + (envelopes: (theme.layout.envelope.din-c4-b,)),
    210mm,
    297mm,
    area-rect,
    first: m.first,
    pitch: m.pitch,
  )
  assert(c4.first().lines == 4)
  let us = R(theme.layout.us-letter-10)
  let thirds = window-fit(
    us + (envelopes: us.envelopes.map(e => e + (fold: (11in / 3, 22in / 3)))),
    215.9mm,
    279.4mm,
    area-rect,
    first: m.first,
    pitch: m.pitch,
  )
  assert(thirds.first().lines < 4)
  // mapping by the SENDER's region
  assert(theme.layout.for-region("ch").name == "sn-010130-right")
  assert(theme.layout.for-region("FR").name == "a4-window-right")
  assert(theme.layout.for-region("xx").name == "din-5008-a")
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
  )
  set text(size: 8pt)
  [line metrics: first #calc.round(m.first / 1mm, digits: 2) mm, pitch #calc.round(m.pitch / 1mm, digits: 2) mm]
  table(
    columns: 5,
    [layout],
    [envelope],
    [lines],
    [line width mm],
    [always-visible band y (2 mm clear)],
    ..out.flatten(),
  )
}
ALL ENVELOPE ASSERTIONS PASSED
