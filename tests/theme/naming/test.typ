// Q7 vocabulary (prototype tests/naming.typ, scripts/checks-naming.sh): the new
// names resolve, the old ones are gone, and the strict merge rejects every old
// key with the list of allowed keys (tytanic `catch`).
#import "/src/lib.typ": *
#import "/src/theming/schema.typ": (
  area-defaults, document-kinds, layout-defaults, marks-template, option-schema,
  token-schema,
)
#import "/src/theming/validate.typ": requirements-table

#let custom = dictionary(theme.custom)
#let T = dictionary(theme)
#let L = dictionary(theme.layout)
#let P = dictionary(theme.parts)

// exports
#assert("resolve" in T and "resolve-theme" not in T)
#assert("us-letter-digital" in L and "letter-digital" not in L)
#assert(
  theme.layout.us-letter-digital.name == "us-letter-digital"
    and theme.layout.us-letter-digital.paper == "us-letter",
)
// helpers: area() replaces region(); the sender option group is gone (helper name == group name)
#assert("area" in custom and "region" not in custom and "sender" not in custom)
#assert("sender" not in option-schema)
// area fields: left/top anchors, `stationery` flag
#for k in ("left", "top", "right", "bottom", "stationery") {
  assert(k in area-defaults, message: k)
}
#for k in ("x", "y", "brand") { assert(k not in area-defaults, message: k) }
#assert("left" in marks-template and "x" not in marks-template)
#assert("areas" in layout-defaults and "regions" not in layout-defaults)
#assert(layout-defaults.stationery == none)
// tokens
#assert(
  token-schema.fonts.keys()
    == ("body", "heading", "label", "numeric", "number-width", "regulated"),
)
#assert(
  token-schema.sizes.keys() == ("body", "small", "fine", "large", "title"),
)
#assert(token-schema.spacing.keys() == ("small", "medium", "leading"))
// options
#assert(option-schema.title.keys() == ("arrange", "show-place-date", "color"))
#assert(
  option-schema.line-items.keys()
    == ("discount-color", "surcharge-color", "gap"),
)
#assert(option-schema.totals.keys() == ("width", "min-width", "fill", "color"))
#assert(option-schema.bank-details.keys() == ("show-qr", "qr-size"))
// parts
#for p in (
  "sender-details",
  "reference-list",
  "registration",
  "notes",
  "payment-terms",
) { assert(p in P, message: p) }
#for p in ("sender-extra", "info-block", "register", "notices") {
  assert(p not in P, message: p)
}
// document kinds and the requirements vocabulary
#assert(
  "proforma-invoice" in document-kinds and "payment-reminder" in document-kinds,
)
#assert("proforma" not in document-kinds and "reminder" not in document-kinds)
#for (role, rule) in requirements-table.invoice.roles {
  assert(
    "waived-by-stationery" in rule and "printed-ok" not in rule,
    message: role,
  )
  assert(rule.where in ("tagged", "first-page"), message: role)
}

// behaviour under the new names
#let R(..p) = theme.resolve(theme.classic.with(..p))
#let t = R({
  import theme.custom: *
  area("address", left: 22mm, top: 40mm)
  title(arrange: "stack", color: red)
  totals(fill: luma(240))
  bank-details(show-qr: false)
  fonts(number-width: "proportional")
  sizes(body: 9pt)
  spacing(small: 0.3em, medium: 0.5em)
  line-items(discount-color: green, surcharge-color: blue)
  marks(left: 6mm)
})
#assert(
  t.layout.areas.address.left == 22mm
    and t.layout.areas.address.top == 40mm
    and t.layout.areas.address.right == auto,
)
#assert(
  t.options.title == (arrange: "stack", show-place-date: true, color: red),
)
#assert(
  t.options.totals.fill == luma(240)
    and t.options.bank-details.show-qr == false,
)
#assert(
  t.tokens.fonts.number-width == "proportional"
    and t.tokens.sizes.body == 9pt
    and t.tokens.spacing == (small: 0.3em, medium: 0.5em, leading: 0.65em),
)
#assert(
  t.options.line-items
    == (discount-color: green, surcharge-color: blue, gap: 0.7em),
)
#assert(t.layout.marks.left == 6mm)
// anchors stay exclusive under the new names: right clears left, bottom clears top
#let u = R(theme.custom.area("address", right: 20mm, bottom: 180mm))
#assert(
  u.layout.areas.address.left == auto and u.layout.areas.address.top == auto,
)
// stationery: none by default; the letterhead and footer belong to it
#let d = R()
#assert(
  d.layout.stationery == none
    and d.layout.areas.letterhead.stationery
    and d.layout.areas.footer.stationery,
)
#assert(
  R(theme.custom.stationery("pre-printed")).layout.stationery == "pre-printed",
)
// a data file speaks the same vocabulary
#assert(
  R(theme.custom.from-data((
    options: (totals: (fill: "#eeeeee")),
    tokens: (sizes: (body: "9pt")),
  )))
    .tokens
    .sizes
    .body
    == 9pt,
)
// env.region still means the sender's COUNTRY (not a page area)
#assert(
  theme
    .resolve(theme.classic, env: (
      kind: "invoice",
      lang: "en",
      region: "us",
      e-invoice: none,
    ))
    .layout
    .name
    == "us-letter-10",
)

// old field names are rejected with the new names listed (strict merge)
#let allowed-area = "place, pages, left, top, right, bottom, width, height, parts, arrange, gap, align, cell-align, par, inset, fill, stroke, radius, rule, text, stationery, isolate, float, reserve"
#let old = (
  (
    () => theme.custom.area("address", x: 20mm),
    "theme::layout::areas::address has unknown key `x`. Allowed keys: "
      + allowed-area,
  ),
  (
    () => theme.custom.area("letterhead", brand: false),
    "theme::layout::areas::letterhead has unknown key `brand`. Allowed keys: "
      + allowed-area,
  ),
  (
    () => (layout: (regions: (address: (width: 80mm)))),
    "theme::layout has unknown key `regions`. Allowed keys: name, paper, flipped, margin, header-ascent, footer-descent, footer-clearance, body-top, body-gap, stationery, marks, envelopes, proof, areas",
  ),
  (
    () => (tokens: (sizes: (base: 9pt))),
    "theme::tokens::sizes has unknown key `base`. Allowed keys: body, small, fine, large, title",
  ),
  (
    () => (options: (bank-details: (qr: false))),
    "theme::options::bank-details has unknown key `qr`. Allowed keys: show-qr, qr-size",
  ),
)
#for (patch, message) in old {
  assert.eq(
    catch(() => theme.resolve(theme.classic.with(patch()))),
    "panicked with: " + repr(message),
  )
}
