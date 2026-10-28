// Frame view additions (prototype tests/api-frame/view.typ, run under strict):
// area.window/place/surface, payment.due, arrange as a function (ctx, cells,
// area), the look-safe area fields cell-align, par, radius and rule, and
// page-number (from: auto labels page 1 of a two-page invoice, ctx-first
// format). One invoice per document.
#import "/tests/theme/body.typ": *
#import theme.custom: *

#let probe(name) = wrap(name, (ctx, view, inner) => {
  [#metadata((
    part: name,
    area: view.area,
    payment: view.payment,
    page: view.page,
  ))<view-probe>]
  inner(ctx, view)
})
// arrange as a function: (ctx, cells, area), cells = array of (name, body)
#let arranged = area("info", parts: ("sender-details", [Free cell]), arrange: (
  ctx,
  cells,
  area,
) => {
  [#metadata((names: cells.map(c => c.first()), area: area))<arrange-probe>]
  stack(spacing: 2mm, ..cells.map(c => c.last()))
})
#let th = theme.classic.with(
  probe("recipient"),
  probe("title"),
  probe("page-number"),
  arranged,
  // look-safe extensions: cell-align, par, radius (derivable), rule
  area(
    "letterhead",
    cell-align: (left + horizon, right + horizon),
    radius: t => t.spacing.small,
    par: (leading: t => t.spacing.small),
  ),
  area("address", fill: luma(245)),
  area("footer", rule: (side: top, gap: 1.5mm)),
  page-number(format: (
    ctx,
    current,
    total,
  ) => [#ctx.locale.lang #current/#total]),
  layout: theme.layout.din-5008-a,
)
#show: invoice.with(
  theme: th,
  locale: test-locale,
  validation: "strict",
  ..party,
  date: datetime(
    year: 2026,
    month: 9,
    day: 1,
  ),
)
#body(n: 30)

#context {
  let v = query(<view-probe>).map(x => x.value)
  let rec = v.find(x => x.part == "recipient")
  assert(rec != none, message: "recipient probe missing")
  assert(
    rec.area.window == true
      and rec.area.place == "fixed"
      and rec.area.name == "address",
    message: "recipient area: " + repr(rec.area),
  )
  assert(
    rec.area.fill == luma(245) and rec.area.surface == luma(245),
    message: "area fill/surface: " + repr(rec.area),
  )
  // due date derived from payment-terms(days: 14) and the invoice date
  assert(rec.payment.days == 14, message: "payment.days " + repr(rec.payment))
  assert(
    rec.payment.due.value == datetime(year: 2026, month: 9, day: 15),
    message: "payment.due " + repr(rec.payment.due),
  )
  assert(
    type(rec.payment.due.text) in (str, content) and rec.payment.due.text != "",
    message: "payment.due.text",
  )
  let ti = v.find(x => x.part == "title")
  assert(
    ti.area.window == false
      and ti.area.place == "before"
      and ti.area.surface == white,
    message: "title area: " + repr(ti.area),
  )
  // page-number: from auto labels page 1 of a multi-page invoice; format is ctx-first
  let pn = v.filter(x => x.part == "page-number")
  assert(
    pn.len() >= 2
      and pn.all(x => x.area.place == "footer" and x.area.window == false),
    message: "page-number probes: " + repr(pn),
  )
  assert(
    pn.any(x => x.page.current == 1 and x.page.total == 2),
    message: "page-number on page 1",
  )
  let a = query(<arrange-probe>).first().value
  assert(
    a.names == ("sender-details", none),
    message: "arrange cells: " + repr(a.names),
  )
  assert(
    a.area.width == 75mm and a.area.height == 40mm,
    message: "arrange area: " + repr(a.area),
  )
}
// the page label is rendered on page 1 (ctx-first format callback)
#context {
  let texts = query(<view-probe>).filter(x => x.value.part == "page-number")
  assert(texts.len() >= 2)
}

// pure API: defaults and the look-safe list
#import "/src/theming/schema.typ": (
  area-style-fields, layout-defaults, option-schema,
)
#for f in ("cell-align", "par", "radius", "rule") {
  assert(f in area-style-fields, message: f + " must be look-safe")
}
#assert(
  layout-defaults.margin.bottom == auto
    and layout-defaults.footer-clearance == 5mm,
)
#let r = theme.resolve(theme.classic)
#assert(r.options.page-number.from == auto and r.options.logo.on-dark == auto)
#assert(r.layout.areas.address.gap == 0pt) // the DIN address rows keep their geometry (rows honour gap)
#for l in (
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
) {
  let t = theme.resolve(theme.classic.with(
    layout: dictionary(theme.layout).at(l),
  ))
  assert(
    t.layout.margin.bottom == auto,
    message: l + ": built-in layouts compute the bottom margin",
  )
}
// margin sides: `auto` in a patch is untouched, reset() returns to the computed default
#let m1 = (
  theme.resolve(theme.classic.with(page(margin: (bottom: 30mm)))).layout.margin
)
#assert(m1.bottom == 30mm and m1.top == 20mm)
#let m2 = (
  theme
    .resolve(theme.classic.with(page(margin: (bottom: 30mm)), page(margin: (
      bottom: auto,
      top: 25mm,
    ))))
    .layout
    .margin
)
#assert(m2.bottom == 30mm and m2.top == 25mm)
#let m3 = (
  theme
    .resolve(theme.classic.with(page(margin: (bottom: 30mm)), page(margin: (
      bottom: reset(),
    ))))
    .layout
    .margin
)
#assert(m3.bottom == auto)
#assert(
  theme
    .resolve(theme.classic.with(page(footer-clearance: 8mm)))
    .layout
    .footer-clearance
    == 8mm,
)
#assert(
  theme
    .resolve(theme.classic.with(theme.custom.from-data((
      layout: (footer-clearance: "7mm", margin: (bottom: "auto")),
    ))))
    .layout
    .footer-clearance
    == 7mm,
)
// rule derivations resolve (whole record and per value)
#let rr = theme.resolve(theme.classic.with(
  area("footer", rule: t => (stroke: t.strokes.thin + t.colors.primary)),
  area("title", rule: (side: bottom, gap: t => t.spacing.small)),
))
#assert(rr.layout.areas.footer.rule.stroke == 0.5pt + rr.tokens.colors.primary)
#assert(rr.layout.areas.title.rule == (side: bottom, gap: 0.4em))
