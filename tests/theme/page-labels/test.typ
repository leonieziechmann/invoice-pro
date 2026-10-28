/// [ppi: 12]

// The ctx-first page-number format gets the document's locale in every
// language (de, en, fr, it, es), and the default label (strings.document.page)
// renders (fr); prototype tests/api-tokens-render.typ. Page counts are checked
// in tests/theme/page-number.
#import "/tests/theme/page-label.typ": *
#import "/tests/theme/harness.typ": case, close-cases, in-case

#let langs = ("de", "en", "fr", "it", "es")
#for lang in langs {
  case(
    lang,
    theme: page-theme(probe-format),
    locale: dictionary(locale).at(lang + "-de"),
    ..party,
    body(n: 30),
  )
}
#case(
  "fr/default",
  theme: page-theme(auto),
  locale: locale.fr-de,
  ..party,
  body(n: 30),
)
#close-cases()
#context for lang in langs {
  let q = in-case(lang, <pn>)
  assert(q.len() >= 2, message: lang + ": format called " + str(q.len()) + "x")
  assert(q.all(v => v.lang == lang), message: lang + ": " + repr(q))
}
