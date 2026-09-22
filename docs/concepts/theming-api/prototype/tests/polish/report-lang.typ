// The draft report speaks the document's language (O5): every issue that can
// reach the report has a text in de, en, fr, it and es; identifiers stay code.
//   --input lang=de|en|fr|it|es  (the rendered report; default de)
#import "/src/lib.typ": *
#import "/src/locale/lang/lang.typ" as langs
#import "/src/locale/lang/base.typ": base-language
#import "/src/theming/validate.typ": requirements-table
#import "/src/validation/render.typ": localized

// every `key:` passed to issue(..) in src/ (scripts/checks-fix-polish.sh greps
// src/ and compares with this list)
#let issue-keys = (
  "contrast",
  "cmyk",
  "envelope",
  "fine-size",
  "footer-fit",
  "iban",
  "identity",
  "logo-alt",
  "overprint",
  "part-empty",
  "part-none",
  "pdf-image-logo",
  "pdf-image-stationery",
  "qr-bill-paper",
  "role",
  "window",
)
// sample args per key (what the call sites pass)
#let samples = (
  contrast: (
    fg-name: "colors::text-muted",
    bg-name: "colors::tint",
    fg: "#999999",
    bg: "#eeeeee",
    ratio: 2.32,
    min: 4.5,
  ),
  cmyk: (path: "theme::tokens::colors::primary"),
  envelope: (
    envelope: "din-c6",
    packet-w: 210.0,
    packet-h: 99.0,
    envelope-w: 162.0,
    envelope-h: 114.0,
  ),
  fine-size: (size: "5pt"),
  footer-fit: (need: 31.2, avail: 20.5, clearance: 4.0),
  iban: (iban: "DE00 1234"),
  identity: (what: "number", shown: "2026-0142"),
  logo-alt: (:),
  overprint: (area: "letterhead", pages: "all"),
  part-empty: (part: "totals"),
  part-none: (part: "recipient"),
  pdf-image-logo: (:),
  pdf-image-stationery: (page: "first"),
  qr-bill-paper: (layout: "us-letter-10"),
  role: (
    role: "recipient",
    why: "recipient name and address",
    layout: "custom",
    parts: ("recipient",),
    exactly: true,
    tagged: true,
    found: 0,
  ),
  window: (area: "info", window: "address"),
)
#assert(samples.keys().sorted() == issue-keys.sorted())

// plain text of rendered content (for assertions)
#let plain(c) = {
  if c == none { "" } else if type(c) == str { c } else if (
    type(c) in (int, float)
  ) { str(c) } else if type(c) == content {
    if c.has("text") { plain(c.text) } else if c.has("children") {
      c.children.map(plain).join()
    } else if c.has("body") { plain(c.body) } else if c.func() == smartquote {
      "'"
    } else if c.func() == [ ].func() {
      " "
    } else { "" }
  } else { "" }
}

#let roles = requirements-table.invoice.roles.keys()
#let all-langs = (
  base: base-language,
  de: langs.de,
  en: langs.en,
  fr: langs.fr,
  it: langs.it,
  es: langs.es,
)
#for (name, l) in all-langs {
  let v = l.validation
  assert(
    v.issues.keys().sorted() == issue-keys.sorted(),
    message: name + ": issue texts " + repr(v.issues.keys().sorted()),
  )
  assert(
    v.roles.keys().sorted() == roles.sorted(),
    message: name + ": role texts",
  )
  for k in issue-keys {
    let out = (v.issues.at(k))(samples.at(k))
    assert(type(out) == content, message: name + ": " + k)
    assert(plain(out).len() > 20, message: name + ": " + k + " is empty")
  }
}
// the localised role text replaces the English `why`
#let role-issue = (key: "role", args: samples.role, message: "english")
#assert(
  plain(localized(langs.de.validation, role-issue)).contains(
    "Rechnungsempfänger:in",
  ),
)
// numbers follow the language: decimal comma in de/fr/it/es, point in en
#let c = (key: "contrast", args: samples.contrast, message: "")
#assert(plain(localized(langs.de.validation, c)).contains("2,32:1"))
#assert(plain(localized(langs.en.validation, c)).contains("2.32:1"))
// a key the locale does not define falls back to the English developer message
#assert(
  plain(localized(
    langs.de.validation + (issues: (:)),
    (key: "iban", args: samples.iban, message: "fallback `x`"),
  )).contains("fallback"),
)

// --- a real draft with an invalid IBAN, a logo without alt text, a fine size
// under 6 pt and a failed contrast pair: the report rows are all localised
#let lang = sys.inputs.at("lang", default: "de")
#let loc = (
  de: locale.de-de,
  en: locale.en-de,
  fr: locale.fr-de,
  it: locale.it-de,
  es: locale.es-de,
).at(lang)
#let strings = all-langs.at(lang).validation
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.logo(image: image("/tests/gallery/pa-mark.svg")),
    theme.custom.sizes(fine: 5.5pt),
    theme.custom.colors(text-muted: rgb("#b0b0b0")),
    theme.custom.checks(min-contrast: 4.5),
  ),
  locale: loc,
  validation: "draft",
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "2026-0142",
)
#line-items[#item([Beratung], price: 100)]
#bank-details(
  iban: "DE00 1234 5678 9012 3456 78",
  bic: "COBADEFFXXX",
  bank: "Bank",
)

#context {
  let issues = query(<ip-issue>).map(m => m.value)
  let ids = issues.map(x => x.id)
  for want in ("iban", "lint/logo-alt", "lint/fine-size") {
    assert(want in ids, message: "expected issue " + want + " in " + repr(ids))
  }
  assert(ids.any(i => i.starts-with("lint/contrast-")), message: repr(ids))
  for x in issues {
    // every theme and lint issue (and the IBAN) carries a localisable key
    if x.field == none {
      assert(
        x.key in issue-keys,
        message: x.id + " has no localised report text",
      )
    }
    let txt = plain(localized(strings, x))
    assert(txt != plain([#x.message]) or lang == "en", message: x.id)
  }
  let row(id) = plain(localized(strings, issues.find(x => x.id == id)))
  let expect = (
    de: ("ist ungültig", "Alternativtext", "absolute Länge"),
    en: ("is not valid", "alt text", "absolute length"),
    fr: ("n'est pas valide", "texte alternatif", "longueur absolue"),
    it: ("non è valido", "testo alternativo", "lunghezza assoluta"),
    es: ("no es válido", "texto alternativo", "longitud absoluta"),
  ).at(lang)
  for (id, needle) in ("iban", "lint/logo-alt", "lint/fine-size").zip(expect) {
    assert(
      row(id).contains(needle),
      message: lang + " " + id + ": " + row(id),
    )
  }
}
