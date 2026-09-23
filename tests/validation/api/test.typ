// The validation API (prototype tests/validation/api.typ): levels, the
// --input invoice-pro-validation precedence in both directions, the strict text,
// theme findings as data on the resolved theme, contrast listing every failing
// pair, report labels for every data requirement in every language, and a
// complete invoice under the default level without any feedback.
#import "/tests/theme/body.typ": *
#import "/src/validation/issue.typ": (
  blocking-classes, classes, dedupe, issue, levels, panic-text, resolve-level,
)

// precedence: sys.inputs wins over the parameter, in both directions
#assert(resolve-level("draft", inputs: (:)) == "draft")
#assert(resolve-level(none, inputs: (:)) == none)
#assert(
  resolve-level("draft", inputs: (invoice-pro-validation: "strict"))
    == "strict",
)
#assert(
  resolve-level("strict", inputs: (invoice-pro-validation: "none")) == none,
)
#assert(
  resolve-level(none, inputs: (invoice-pro-validation: "draft")) == "draft",
)
#assert(levels == (none, "draft", "strict"))
#assert(blocking-classes == ("data", "e-invoice"))

// strict text: one issue verbatim, several with a header and a numbered list
#let a = issue("a", "data", "A is missing")
#let b = issue("b", "lint", "B is off")
#assert(panic-text((a,)) == "A is missing")
#assert(panic-text((a, b)).starts-with("invoice-pro found 2 problems"))
#assert(dedupe((a, b, a)) == (a, b))

// theme findings are data on the resolved theme; misuse would have panicked
#let t = theme.resolve(
  theme.classic.with(
    theme.custom.area("address", none),
    theme.custom.sizes(fine: 5pt),
  ),
  validation: "draft",
)
#assert(
  t.issues.map(x => x.id) == ("lint/fine-size", "theme/role-recipient"),
  message: repr(t.issues.map(x => x.id)),
)
#assert(t.issues.map(x => x.class) == ("lint", "theme"))
#assert(theme.resolve(theme.classic).issues == ())
#assert(theme.resolve(theme.corporate).issues == ())
#assert(theme.resolve(theme.boxed).issues == ())
#assert(theme.resolve(theme.plain).issues == ())
// contrast lists every failing pair, not just the first
#let c = theme.resolve(
  theme.classic.with(
    theme.custom.checks(min-contrast: 4.5),
    theme.custom.colors(text-muted: rgb("#f472b6")),
  ),
  validation: none,
)
#assert(c.issues.len() == 2 and c.issues.all(x => x.class == "lint"))

// every data requirement row has a label in every language
#import "/src/validation/data.typ": data-requirements
#import "/src/locale/lang/lang.typ" as langs
#import "/src/locale/lang/base.typ": base-language
#for l in (base-language, langs.de, langs.en, langs.fr, langs.it, langs.es) {
  let f = l.validation.fields
  for r in data-requirements.invoice {
    assert(r.field in f, message: l.meta.lang + ": " + r.field)
  }
  for k in (
    "buyer-electronic-address",
    "seller-electronic-address",
    "buyer-reference",
    "seller-contact-name",
    "seller-contact-phone",
    "seller-contact-email",
  ) {
    assert(k in f, message: l.meta.lang + ": " + k)
  }
  assert(l.validation.classes.keys() == classes)
  assert(
    l.validation.keys() == base-language.validation.keys(),
    message: l.meta.lang,
  )
}

// a complete invoice under the default level renders without any feedback
#show: invoice.with(locale: test-locale, ..party)
#body()
#context assert(query(<ip-issue>).len() == 0 and query(<ip-report>).len() == 0)
