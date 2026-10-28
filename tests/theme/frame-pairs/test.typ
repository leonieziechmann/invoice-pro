/// [ppi: 12]

// Frame render pairs (prototype tests/api-frame/pairs.typ, checks-api-frame.sh):
// each case renders variant a and b; the prototype compared the two PNGs, here
// a probe inside the part asserts what the knob changes (or provably does not):
// - legal-fill: legal footer parts inherit the area's text colour;
// - logo-dark: on a dark letterhead the logo gets a plate unless on-dark: none;
// - logo-light: on a light letterhead on-dark has no effect;
// - logo-alt: a replacement logo for dark surfaces;
// - rows-gap: the address rows honour `gap`;
// - cell-align and par: look-safe letterhead fields reach the parts;
// - rule-height: an area rule is zero-height, it moves nothing.
// `radius` and `rule` only paint: tests/theme/knobs (visual); `page-from`:
// tests/theme/page-number-from.
#import "/tests/theme/body.typ": *
#import "/tests/theme/harness.typ": case, close-cases, in-case
#import theme.custom: *

#let dark = area("letterhead", fill: rgb("#1c1a17"), text: (fill: white))
#let light = area("letterhead", fill: rgb("#f4f1ea"))
#let patches = (
  legal-fill: v => area("footer", text: (fill: v(red, blue))),
  logo-dark: v => (dark, logo(on-dark: v(auto, none))),
  logo-light: v => (light, logo(on-dark: v(auto, none))),
  logo-alt: v => (
    dark,
    logo(on-dark: v(auto, box(width: 30mm, height: 10mm, stroke: white))),
  ),
  rows-gap: v => area("address", gap: v(0pt, 4mm)),
  cell-align: v => area("letterhead", cell-align: v(auto, (
    right + top,
    left + bottom,
  ))),
  par: v => area("letterhead", par: v((:), (leading: 1.2em))),
  rule-height: v => area("footer", rule: v(none, (
    side: top,
    gap: 1mm,
    stroke: 0.5pt + white,
  ))),
)
// every probed part reports its position, its text fill, alignment and paragraph
// leading, and what it rendered
#let probe(name) = wrap(name, (ctx, view, inner) => {
  let out = inner(ctx, view)
  context [#metadata((
    part: name,
    x: here().position().x,
    y: here().position().y,
    fill: text.fill,
    align: align.alignment,
    leading: par.leading,
    plate: (
      type(out) == content
        and out.func() == box
        and out.fields().at("fill", default: none) == white
    ),
    // the 30 mm replacement box of the logo-alt pair
    alt: (
      type(out) == content
        and out.func() == box
        and type(out.at("body", default: none)) == content
        and out.body.func() == box
        and out.body.fields().at("width", default: none) == 30mm
    ),
    out: repr(out),
  ))<pair-probe>]
  out
})
#let probes = ("logo", "sender", "recipient", "registration").map(probe)
#for (name, patch) in patches {
  for v in ("a", "b") {
    case(
      name + "/" + v,
      theme: theme.classic.with(
        brand(logo: logo-img),
        patch((a, b) => if v == "a" { a } else { b }),
        ..probes,
        layout: theme.layout.din-5008-a,
      ),
      locale: test-locale,
      ..party,
      body(n: 4),
    )
  }
}
#close-cases()

#context {
  let at(name, v, part) = {
    let p = in-case(name + "/" + v, <pair-probe>).filter(x => x.part == part)
    assert(
      p.len() >= 1,
      message: name + "/" + v + ": " + part + " not rendered",
    )
    p.first()
  }
  let pair(name, part) = (at(name, "a", part), at(name, "b", part))

  let (a, b) = pair("legal-fill", "registration")
  assert(
    a.fill == red and b.fill == blue,
    message: "legal-fill: " + repr((a.fill, b.fill)),
  )

  let (a, b) = pair("logo-dark", "logo")
  assert(
    a.plate and not b.plate,
    message: "logo-dark: plate " + repr((a.plate, b.plate)),
  )

  let (a, b) = pair("logo-light", "logo")
  assert(
    not a.plate and a.out == b.out,
    message: "logo-light: on-dark must not matter",
  )

  let (a, b) = pair("logo-alt", "logo")
  assert(
    a.plate and not a.alt and not b.plate and b.alt,
    message: "logo-alt: the replacement logo is not drawn: " + b.out,
  )

  let (a, b) = pair("rows-gap", "recipient")
  assert(
    calc.abs((b.y - a.y) - 4mm) < 0.01mm,
    message: "rows-gap: the recipient row moved " + repr(b.y - a.y),
  )

  // cell-align wins over the layout's arrange.align (left + horizon, right + top)
  let (a, b) = pair("cell-align", "logo")
  let (sa, sb) = pair("cell-align", "sender")
  assert(
    (a.align, sa.align) == (left + horizon, right + top)
      and (b.align, sb.align) == (right + top, left + bottom),
    message: "cell-align: " + repr(((a.align, sa.align), (b.align, sb.align))),
  )

  let (a, b) = pair("par", "sender")
  assert(
    a.leading == 0.5em and b.leading == 1.2em,
    message: "par: leading " + repr((a.leading, b.leading)),
  )

  let (a, b) = pair("rule-height", "registration")
  assert(
    (a.x, a.y) == (b.x, b.y),
    message: "rule-height: the footer rule moved the footer",
  )
}
